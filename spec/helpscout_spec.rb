require 'spec_helper'

describe HelpScout do
  let(:client) { HelpScout.new("api_key") }

  describe '#create_conversation' do
    it 'returns the conversation id' do
      data = { subject: "Help me!" }

      url = 'https://api.helpscout.net/v1/conversations.json'
      stub_request(:post, url).
        to_return(
          status: 201,
          headers: {
            location: 'https://api.helpscout.net/v1/conversations/123.json'
          },
          body: data.to_json,
        )
      expect(client.create_conversation(data)).to eq '123'
    end

    context 'with invalid input' do
      it 'returns validation errors' do
        data = { subject: "Help me!", customer: { email: "" } }

        url = 'https://api.helpscout.net/v1/conversations.json'
        stub_request(:post, url).
          to_return(
            status: 400,
            headers: {
               'Content-Type' => 'application/json'
            },
            body: { error: "Input could not be validated", message: "Email is not valid" }.to_json
          )

        expect { client.create_conversation(data) }.to raise_error(HelpScout::ValidationError, "Email is not valid")
      end
    end

    context 'with a not implemented status code' do
      it 'returns a not implemented error' do
        data = { subject: "Help me!" }

        url = 'https://api.helpscout.net/v1/conversations.json'
        stub_request(:post, url).
          to_return(
            status: 500,
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
      url = 'https://api.helpscout.net/v1/search/conversations.json?page=1&query=(tag:conversion)'
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
      url = 'https://api.helpscout.net/v1/conversations/4242.json'
      req = stub_request(:post, url).
        with(body: thread.to_json).
        to_return(status: 201)

      expect(client.create_thread(conversation_id: 4242, thread: thread)).
        to eq(true)
      expect(req).to have_been_requested
    end
  end
end
