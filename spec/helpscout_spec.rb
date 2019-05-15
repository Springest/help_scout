require 'spec_helper'

describe HelpScout do
  let(:client) { HelpScout.new("api_key", "api_secret") }

  before(:each) do
    stub_request(:post, 'https://api.helpscout.net/v2/oauth2/token').to_return(
      status: 200,
      body: {
        access_token: 'YXBpX2tleTpY'
      }.to_json
    )
  end

  describe '#create_conversation' do
    it 'returns the conversation id' do
      data = { subject: "Help me!" }

      url = 'https://api.helpscout.net/v2/conversations'
      stub_request(:post, url).
        to_return(
          status: 201,
          headers: {
            location: 'https://api.helpscout.net/v2/conversations/123'
          },
          body: data.to_json,
        )
      expect(client.create_conversation(data)).to eq '123'
    end

    context 'with invalid input' do
      it 'returns validation errors' do
        data = { subject: "Help me!", customer: { email: "foo@hotmail.con" } }

        url = 'https://api.helpscout.net/v2/conversations'
        stub_request(:post, url).
          to_return(
            status: 400,
            headers: {
               'Content-Type' => 'application/json'
            },
            body: {
              "error" => "Input could not be validated",
              "validationErrors" => [
                {
                  "property" => "customer:email",
                  "value" => "foo@hotmail.con",
                  "message" => "Email is not valid"
                }
              ]
            }.to_json
          )

        expect { client.create_conversation(data) }.to raise_error(HelpScout::ValidationError, '[{"property"=>"customer:email", "value"=>"foo@hotmail.con", "message"=>"Email is not valid"}]')
      end
    end

    context 'with a 403 status code' do
      it 'returns ForbiddenError' do
        url = 'https://api.helpscout.net/v2/conversations/1337'
        stub_request(:get, url).to_return(status: 403)

        expect { client.get_conversation(1337) }.to raise_error(HelpScout::ForbiddenError)
      end
    end

    context 'with a 404 status code' do
      it 'returns NotFoundError' do
        url = 'https://api.helpscout.net/v2/conversations/1337'
        stub_request(:get, url).to_return(status: 404)

        expect { client.get_conversation(1337) }.to raise_error(HelpScout::NotFoundError)
      end
    end

    context 'with a 500 status code' do
      it 'returns InternalServerError with body' do
        expected_error_message = "Did not find any valid email for customer 1111"

        url = 'https://api.helpscout.net/v2/conversations/1337'
        stub_request(:post, url).
          to_return(
            status: 500,
            body: {
              "code": 500,
              "error": expected_error_message,
            }.to_json,
        )

        expect {
          client.create_thread(conversation_id: 1337, thread: {})
        }.to raise_error(HelpScout::InternalServerError, expected_error_message)
      end
    end

    context 'with a 503 status code' do
      it 'returns ServiceUnavailable' do
        url = 'https://api.helpscout.net/v2/conversations/1337'
        stub_request(:get, url).to_return(status: 503)

        expect { client.get_conversation(1337) }.to raise_error(HelpScout::ServiceUnavailable)
      end
    end

    context 'with a not implemented status code' do
      it 'returns a not implemented error' do
        data = { subject: "Help me!" }

        url = 'https://api.helpscout.net/v2/conversations'
        stub_request(:post, url).
          to_return(
            status: 402,
          )

        expect { client.create_conversation(data) }.to raise_error(HelpScout::NotImplementedError)
      end
    end
  end

  describe '#search_conversations' do
    let(:conversations) do
      {
        "page" => 1,
        "pages" => 1,
        "count" => 1,
        "items" => [
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
        ],
      }
    end

    it 'does the correct query' do
      url = 'https://api.helpscout.net/v2/search/conversations?page=1&query=(tag:conversion)'
      stub_request(:get, url).
        to_return(
          status: 200,
          headers: {
            "Content-Type" => "application/json; charset=utf-8",
          },
          body: conversations.to_json,
        )
      expect(client.search_conversations("tag:conversion")).to eq conversations["items"]
    end
  end

  describe '#create_thread' do
    let(:thread) do
      {
        createdBy: {
          type: 'user',
          id: 42,
        },
        type: 'note',
        body: "Hello, I'm a noteworthy!"
      }
    end

    it 'does the correct query' do
      url = 'https://api.helpscout.net/v2/conversations/4242'
      request = stub_request(:post, url).
        with(body: thread.to_json).
        to_return(status: 201)

      expect(client.create_thread(conversation_id: 4242, thread: thread)).
        to eq(true)
      expect(request).to have_been_requested
    end

    it 'returns response when reload true' do
      url = 'https://api.helpscout.net/v2/conversations/4242?reload=true'
      request = stub_request(:post, url).
        with(body: thread.to_json).
        to_return(status: 201, body: "conversation")

      expect(client.create_thread(conversation_id: 4242, thread: thread, reload: true)).
        to eq("conversation")
    end
  end

  describe '#update_thread' do
    let(:thread) do
      {
        id: 12345,
        body: "Hello, I'm a noteworthy!"
      }
    end

    it 'does the correct query' do
      url = 'https://api.helpscout.net/v2/conversations/4242/threads/12345'
      request = stub_request(:put, url).
        with(body: ({ body: thread[:body] }).to_json).
        to_return(status: 200)

      expect(client.update_thread(conversation_id: 4242, thread: thread)).
        to eq(true)
      expect(request).to have_been_requested
    end

    it 'returns response when reload true' do
      url = 'https://api.helpscout.net/v2/conversations/4242/threads/12345?reload=true'
      request = stub_request(:put, url).
        with(body: ({ body: thread[:body] }).to_json).
        to_return(status: 200, body: "conversation")

      expect(client.update_thread(conversation_id: 4242, thread: thread, reload: true)).
        to eq("conversation")
    end
  end

  describe '#update_customer' do
    let(:data) { { "firstName" => "Bob" } }

    it 'does the correct query' do
      url = 'https://api.helpscout.net/v2/customers/1337'
      request = stub_request(:put, url).
        with(body: data.to_json).
        to_return(status: 201)

      client.update_customer(1337, data)
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

  describe 'general rate limiting error' do
    it 'returns TooManyRequestsError' do
      url = 'https://api.helpscout.net/v2/conversations/1337'
      stub_request(:get, url).
        to_return(
          status: 429,
          headers: {
            retry_after: '10',
          }
        )

      error_message = "Rate limit of 200 RPM or 12 POST/PUT/DELETE requests per 5 seconds reached. Next request possible in 10 seconds."
      expect { client.get_conversation(1337) }.to raise_error(HelpScout::TooManyRequestsError, error_message)
    end
  end

  it "sends Content-Type when body" do
      url = "https://api.helpscout.net/v2/conversations/4242"
      stub_request(:delete, url).to_return(status: 200)
      stub_request(:put, url).to_return(status: 200)

      client.delete_conversation(4242)
      expect(WebMock).to have_requested(:delete, url).with(headers: {
        "Authorization": "Bearer YXBpX2tleTpY"
      })

      client.update_conversation(4242, subject: "Hello World")
      expect(WebMock).to have_requested(:put, url).with(headers: {
        "Authorization": "Bearer YXBpX2tleTpY",
        "Content-Type": "application/json"
      })

  end
end
