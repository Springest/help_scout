require 'spec_helper'

describe HelpScout do
  let(:client) {
    HelpScout::Client.new("api_key")
  }
  describe '#create_conversation' do
    it 'returns the conversation id' do
      data = { subject: "Help me!" }
      url = 'https://api.helpscout.net/v1/conversations.json'

      stub_request(:post, url).
        to_return(
          status: 201,
          body: data.to_json,
          headers: {
            location: 'https://api.helpscout.net/v1/conversations/123.json'
          }
        )
      expect(client.create_conversation(data)).to eq '123'
    end
  end
end
