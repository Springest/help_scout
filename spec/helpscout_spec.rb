require "spec_helper"

describe HelpScout do
  USER_ID = 123

  let(:client) { HelpScout.new("api_key", "api_secret") }

  let(:mailbox_id) { "123" }

  before(:each) do
    stub_request(:post, "https://api.helpscout.net/v2/oauth2/token").to_return(
      status: 200,
      body: {
        access_token: "ACCESS_TOKEN"
      }.to_json
    )
  end

  context "token storage" do
    it "reuses stored token" do
      token_stub = stub_request(:post, "https://api.helpscout.net/v2/oauth2/token").to_return(
        status: 200,
        body: {
          access_token: "ACCESS_TOKEN"
        }.to_json
      )

      url = "https://api.helpscout.net/v2/conversations/1337"
      stub_request(:get, url).
        with(headers: { "Authorization" => "Bearer"}).
        to_return(status: HelpScout::HTTP_UNAUTHORIZED)

      url = "https://api.helpscout.net/v2/conversations/1337"
      stub_request(:get, url).
        with(headers: { "Authorization" => "Bearer ACCESS_TOKEN"}).
        to_return(status: 200)

      client.get_conversation(1337)
      client.get_conversation(1337)

      expect(token_stub).to have_been_requested.once
    end
  end

  describe "#create_conversation" do
    it "returns the conversation id" do
      data = {
        subject: "Help me!",
        type: "email",
        mailboxId: mailbox_id,
        status: "active",
        customer: {
          email: "springest@example.com"
        },
        threads: [
          {
            type: "phone",
            text: "We had a nice chat",
            customer: {
              email: "springest@example.com"
            }
          }
        ],
      }

      url = "https://api.helpscout.net/v2/conversations"
      stub_request(:post, url).
        to_return(
          status: 201,
          headers: {
            location: "https://api.helpscout.net/v2/conversations/123",
            resource_id: "123",
          },
          body: data.to_json,
        )
      expect(client.create_conversation(data)).to eq "123"
    end

    context "with invalid input" do
      it "returns validation errors" do
        # Missing subject in this data
        data = {
          type: "email",
          mailboxId: mailbox_id,
          status: "active",
          customer: {
            email: "springest@example.com"
          },
          threads: [
            {
              type: "reply",
              text: "Message via HelpScout",
              customer: {
                email: "springest@example.com"
              }
            }
          ],
        }

        response_body = {
          "logRef" => "reference",
          "message" => "Bad request",
          "_embedded" => {
            "errors" => [
              {
                "path" => "subject",
                "message" => "must not be empty",
                "source" => "JSON",
                "_links" => {
                  "about" => {
                    "href" => "http://developer.helpscout.net/mailbox-api/overview/errors#NotEmpty"
                  }
                }
              }
            ]
          },
          "_links" => {
            "about" => {
              "href" =>"http://developer.helpscout.net/mailbox-api/overview/errors"
            }
          }
        }

        errors = [
          {
            "path" => "subject",
            "message" => "must not be empty",
            "source" => "JSON",
            "_links" => {
              "about" => {
                "href" => "http://developer.helpscout.net/mailbox-api/overview/errors#NotEmpty"
              }
            }
          }
        ]

        url = "https://api.helpscout.net/v2/conversations"
        stub_request(:post, url).
          to_return(
            status: 400,
            headers: {
              content_type: ["application/vnd.error+json"],
              location: "https://api.helpscout.net/v2/conversations/123",
              resource_id: "123",
            },
            body: response_body.to_json
          )

        expect { client.create_conversation(data) }.to raise_error(HelpScout::ValidationError, errors.to_json)
      end
    end

    context "with a 403 status code" do
      it "returns ForbiddenError" do
        url = "https://api.helpscout.net/v2/conversations/1337"
        stub_request(:get, url).to_return(status: 403)

        expect { client.get_conversation(1337) }.to raise_error(HelpScout::ForbiddenError)
      end
    end

    context "with a 404 status code" do
      it "returns NotFoundError" do
        url = "https://api.helpscout.net/v2/conversations/1337"
        stub_request(:get, url).to_return(status: 404)

        expect { client.get_conversation(1337) }.to raise_error(HelpScout::NotFoundError)
      end
    end
  end

  describe "#search_conversations" do
    let(:conversations) do
      {
        "page" => {
          "size" => 50,
          "totalElements" => 1,
          "totalPages" => 1,
          "number" => 1
        },
        "_embedded" => {
          "conversations" => [
            {
              "id" => 2391938111,
              "number" => "349",
              "mailboxid" => 1234,
              "subject" => "I need help!",
              "status" => "active",
              "threadCount" => 3,
              "preview" => "Hello, I tried to download the file off your site...",
              "customerName" => "John Appleseed",
              "customerEmail" => "john@appleseed.com",
              "modifiedAt" => "2012-07-24T20:18:33Z",
            }
          ]
        }
      }
    end

    it "does the correct query" do
      url = "https://api.helpscout.net/v2/conversations?page=1&query=(tag:conversion)"
      stub_request(:get, url).
        to_return(
          status: 200,
          headers: {
            "Content-Type" => "application/json; charset=utf-8",
          },
          body: conversations.to_json,
        )
      expect(client.search_conversations("tag:conversion")).to eq conversations["_embedded"]["conversations"]
    end
  end

  describe "#create_thread" do
    it "does the correct query" do
      thread = {
        text: "Note content",
        user: USER_ID,
        imported: false,
      }

      url = "https://api.helpscout.net/v2/conversations/4242/notes"
      request = stub_request(:post, url).
        with(body: thread.to_json).
        to_return(status: 201)

      expect(client.create_note(conversation_id: 4242, user: USER_ID, text: "Note content")).
        to eq(true)
      expect(request).to have_been_requested
    end
  end

  describe "#update_customer" do

    it "does the correct query" do
      customer_data = {
        "firstName" => "Bob"
      }
      url = "https://api.helpscout.net/v2/customers/1337"
      request = stub_request(:put, url).
        with(body: customer_data.to_json).
        to_return(status: 201)

      client.update_customer(1337, customer_data)
      expect(request).to have_been_requested
    end
  end

  describe "#delete_conversation" do
    it "deletes the conversation" do
      url = "https://api.helpscout.net/v2/conversations/4242"

      request = stub_request(:delete, url).to_return(status: 200)

      client.delete_conversation(4242)
      expect(request).to have_been_requested
    end
  end

  describe "general rate limiting error" do
    it "returns TooManyRequestsError" do
      url = "https://api.helpscout.net/v2/conversations/1337"
      stub_request(:get, url).
        to_return(
          status: 429,
          headers: {
            "X-RateLimit-Retry-After": "10",
          }
        )

      error_message = "Rate limit of 200 RPM or 12 POST/PUT/DELETE requests per 5 seconds reached. Next request possible in 10 seconds."
      expect { client.get_conversation(1337) }.to raise_error(HelpScout::TooManyRequestsError, error_message)
    end
  end
end
