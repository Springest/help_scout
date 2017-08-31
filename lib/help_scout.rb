require "help_scout/version"
require "httparty"

class HelpScout
  class ValidationError < StandardError; end
  class NotImplementedError < StandardError; end
  class NotFoundError < StandardError; end
  class InternalServerError < StandardError; end

  # Status codes used by Help Scout, not all are implemented in this gem yet.
  # http://developer.helpscout.net/help-desk-api/status-codes/
  HTTP_OK = 200
  HTTP_CREATED = 201
  HTTP_NO_CONTENT = 204
  HTTP_BAD_REQUEST = 400
  HTTP_NOT_FOUND = 404
  HTTP_INTERNAL_SERVER_ERROR = 500

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

    # Extract ID of created conversation from the Location header
    conversation_uri = last_response.headers["location"]
    conversation_uri.match(/(\d+)\.json$/)[1]
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

  # Public: Creates conversation thread
  #
  # conversion_id - conversation id
  # thread - thread content to be created
  # imported - When set to true no outgoing emails or notifications will be
  #            generated
  # reload - Set to true to get the entire conversation in the result
  #
  # More info: http://developer.helpscout.net/help-desk-api/conversations/create-thread/
  #
  # Returns true if created, false otherwise
  def create_thread(conversation_id:, thread:, imported: nil, reload: nil)
    query = {}
    { reload: reload, imported: imported }.each do |key, value|
      query[key] = value unless value.nil?
    end

    post("conversations/#{conversation_id}", body: thread, query: query)

    last_response.code == HTTP_CREATED
  end

  # Public: Update Customer
  #
  # id - customer id
  # data - hash with data
  #
  # More info: http://developer.helpscout.net/help-desk-api/customers/update/
  def update_customer(id, data)
    put("customers/#{id}", { body: data })
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

    case @last_response.code
    when HTTP_OK, HTTP_CREATED, HTTP_NO_CONTENT
      @last_response.parsed_response
    when HTTP_BAD_REQUEST
      raise ValidationError, last_response.parsed_response["message"]
    when HTTP_NOT_FOUND
      raise NotFoundError
    when HTTP_INTERNAL_SERVER_ERROR
      raise InternalServerError
    else
      raise NotImplementedError, "Help Scout returned something that is not implemented by the help_scout gem yet: #{@last_response.code}: #{@last_response.parsed_response["message"] if @last_response.parsed_response}"
    end
  end
end
