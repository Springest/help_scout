require "help_scout/version"
require "httparty"

class HelpScout
  class ValidationError < StandardError; end
  class NotImplementedError < StandardError; end

  HTTP_CREATED = 201
  HTTP_BAD_REQUEST = 400

  attr_accessor :last_response

  def initialize(api_key)
    @api_key = api_key
  end

  # Public: Create conversation
  #
  # data - hash with data
  #
  # More info: http://developer.helpscout.net/help-desk-api/conversations/create/
  #
  # Returns conversation ID
  def create_conversation(data)
    post("conversations", { body: data })

    if last_response.code == HTTP_CREATED
      # Extract ID of created conversation from the Location header
      conversation_uri = last_response.headers["location"]
      return conversation_uri.match(/(\d+)\.json$/)[1]
    elsif last_response.code == HTTP_BAD_REQUEST
      # Validation failed so return the errors
      raise ValidationError, last_response.parsed_response["message"]
    else
      raise NotImplementedError, "Help Scout returned something that is not implemented by the help_scout gem yet: #{last_response.code}: #{last_response.parsed_response["message"] if last_response.parsed_response}"
    end
  end

  # Public: Get conversation
  #
  # id - conversation ID
  #
  # More info: http://developer.helpscout.net/help-desk-api/objects/conversation/
  #
  # Returns hash from HS with conversation data
  def get_conversation(id)
    get("conversations/#{id}")
  end

  # Public: Get conversations
  #
  # mailbox_id - ID of mailbox (find these with get_mailboxes)
  # page - integer of page to fetch (default: 1)
  # modified_since - Only return conversations that have been modified since
  #                  this UTC datetime (default: nil)
  #
  # More info: http://developer.helpscout.net/help-desk-api/conversations/list/
  #
  # Returns hash from HS with conversation data
  def get_conversations(mailbox_id, page = 1, modified_since = nil)
    options = {
      query: {
        page: page,
        modifiedSince: modified_since,
      }
    }

    get("mailboxes/#{mailbox_id}/conversations", options)
  end

  # Public: Update conversation
  #
  # id - conversation id
  # data - hash with data
  #
  # More info: http://developer.helpscout.net/help-desk-api/conversations/update/
  def update_conversation(id, data)
    put("conversations/#{id}", { body: data })
  end

  # Public: Search for conversations
  #
  # query - term to search for
  #
  # More info: http://developer.helpscout.net/help-desk-api/search/conversations/
  def search_conversations(query)
    search("search/conversations", query)
  end

  # Public: Get customer
  #
  # id - customer id
  #
  # More info: http://developer.helpscout.net/help-desk-api/customers/get/
  def get_customer(id)
    get("customers/#{id}")
  end

  def get_mailboxes
    get("mailboxes")
  end

  # Public: Get ratings
  #
  # More info: http://developer.helpscout.net/help-desk-api/reports/user/ratings/
  # 'rating' parameter required: 0 (for all ratings), 1 (Great), 2 (Okay), 3 (Not Good)
  def reports_user_ratings(user_id, rating, start_date, end_date, options)
    options = {
      user: user_id,
      rating: rating,
      start: start_date,
      end: end_date,
    }

    get("reports/user/ratings", options)
  end

  protected

  def post(path, options = {})
    options[:body] = options[:body].to_json if options[:body]

    request(:post, path, options)
  end

  def put(path, options = {})
    options[:body] = options[:body].to_json if options[:body]

    request(:put, path, options)
  end

  def get(path, options = {})
    request(:get, path, options)
  end

  def search(path, query, page_id = 1, items = [])
    options = { query: { page: page_id, query: "(#{query})" } }

    result = get(path, options)
    if !result.empty?
      next_page_id = page_id + 1
      result["items"] += items
      if next_page_id > result["pages"]
        return result["items"]
      else
        search(path, query, next_page_id, result["items"])
      end
    end
  end

  def request(method, path, options)
    uri = URI("https://api.helpscout.net/v1/#{path}.json")

    # The password can be anything, it's not used, see:
    # http://developer.helpscout.net/help-desk-api/
    options = {
      basic_auth: {
        username: @api_key, password: 'X'
      },
      headers: {
        'Content-Type' => 'application/json'
      }
    }.merge(options)

    @last_response = HTTParty.send(method, uri, options)
    @last_response.parsed_response
  end
end
