require "help_scout/version"
require "httparty"

class DefaultTokenStorage
  def token
    @token
  end

  def store_token(token)
    @token = token
  end
end

class HelpScout
  class ValidationError < StandardError; end
  class NotImplementedError < StandardError; end
  class NotFoundError < StandardError; end
  class TooManyRequestsError < StandardError; end
  class InternalServerError < StandardError; end
  class ForbiddenError < StandardError; end
  class ServiceUnavailable < StandardError; end

  class InvalidDataError < StandardError; end

  # Status codes used by Help Scout, not all are implemented in this gem yet.
  # https://developer.helpscout.com/mailbox-api/overview/status_codes/
  HTTP_OK = 200
  HTTP_CREATED = 201
  HTTP_NO_CONTENT = 204
  HTTP_BAD_REQUEST = 400
  HTTP_UNAUTHORIZED = 401
  HTTP_FORBIDDEN = 403
  HTTP_NOT_FOUND = 404
  HTTP_TOO_MANY_REQUESTS = 429
  HTTP_INTERNAL_SERVER_ERROR = 500
  HTTP_SERVICE_UNAVAILABLE = 503

  # https://developer.helpscout.com/mailbox-api/endpoints/conversations/list/
  CONVERSATION_STATUSES = ["active", "closed", "open", "pending", "spam"]

  # https://developer.helpscout.com/mailbox-api/overview/authentication/#client-credentials-flow
  def generate_oauth_token
    options = {
      headers: {
        "Content-Type": "application/json"
      },
      body: {
        grant_type: "client_credentials",
        client_id: @api_key,
        client_secret: @api_secret,
      }
    }
    options[:body] = options[:body].to_json
    response = HTTParty.post("https://api.helpscout.net/v2/oauth2/token", options)
    JSON.parse(response.body)["access_token"]
  end

  attr_accessor :last_response

  def initialize(api_key, api_secret, token_storage = DefaultTokenStorage.new)
    @api_key = api_key
    @api_secret = api_secret
    @token_storage = token_storage
  end

  # Public: Create conversation
  #
  # data - hash with data
  # note: since v2 the status is now required, which had a default of "active" in v1.
  #
  # More info: https://developer.helpscout.com/mailbox-api/endpoints/conversations/create/
  #
  # Returns conversation ID
  def create_conversation(data)
    # required_fields = ["subject", "type", "mailboxId", "status", "customer", "threads"]

    post("conversations", { body: data })

    last_response.headers["Resource-ID"]
  end

  # Public: Get conversation
  #
  # id - conversation ID
  # embed_threads - boolean - This will load in subentities, currently only
  # Threads are supported by HS
  #
  # More info: https://developer.helpscout.com/mailbox-api/endpoints/conversations/get/
  #
  # Returns hash from HS with conversation data
  def get_conversation(id, embed_threads: false)
    if embed_threads
      get("conversations/#{id}?embed=threads")
    else
      get("conversations/#{id}")
    end
  end

  # Public: Update conversation
  #
  # id - conversation id
  # data - hash with data
  #
  # More info: https://developer.helpscout.com/mailbox-api/endpoints/conversations/update/
  def update_conversation(id, data)
    instructions = []

    if data[:subject]
      instructions << {
        op: "replace",
        path: "/subject",
        value: data[:subject],
      }
    end
    if data[:mailboxId]
      instructions << {
        op: "move",
        path: "/mailboxId",
        value: data[:mailboxId],
      }
    end
    if data[:status]
      status = data[:status]
      if !CONVERSATION_STATUSES.include?(status)
        raise InvalidDataError.new("status \"#{status}\" not supported, must be one of #{CONVERSATION_STATUSES}")
      end

      instructions << {
        op: "replace",
        path: "/status",
        value: data[:status],
      }
    end
    if data.key?(:assignTo)
      # change owner
      if data[:assignTo]
        instructions << {
          op: "replace",
          path: "/assignTo",
          value: data[:assignTo],
        }
      else
        # un assign
        instructions << {
          op: "remove",
          path: "/assignTo",
        }
      end
    end

    # Note: HelpScout currently does not support multiple
    # instructions in the same request, well have to do them
    # individually :-)
    instructions.each do |instruction|
      patch("conversations/#{id}", { body: instruction })
    end
  end

  # Public: Update conversation tags
  #
  # More info: https://developer.helpscout.com/mailbox-api/endpoints/conversations/tags/update/
  def update_conversation_tags(id, tags)
    data = { tags: tags }
    put("conversations/#{id}/tags", { body: data })
  end

  # Public: Update conversation custom fields
  #
  # More info: https://developer.helpscout.com/mailbox-api/endpoints/conversations/custom_fields/update/
  def update_conversation_custom_fields(id, fields)
    data = { fields: fields }
    put("conversations/#{id}/fields", { body: data })
  end

  # Public: Search for conversations
  #
  # query - term to search for
  #
  # More info: https://developer.helpscout.com/mailbox-api/endpoints/conversations/list/
  def search_conversations(query)
    search("conversations", query)
  end

  # Public: Delete conversation
  #
  # id - conversation id
  #
  # More info: https://developer.helpscout.com/mailbox-api/endpoints/conversations/delete/
  def delete_conversation(id)
    delete("conversations/#{id}")
  end

  # Public: List all mailboxes
  #
  # More info: https://developer.helpscout.com/mailbox-api/endpoints/mailboxes/list/
  def get_mailboxes
    get("mailboxes")
  end

  # Public: Create note thread
  #
  # imported: no outgoing e-mails or notifications will be generated
  #
  # More info: https://developer.helpscout.com/mailbox-api/endpoints/conversations/threads/note/
  def create_note(conversation_id:, text:, user: nil, imported: false)
    data = {
      text: text,
      user: user,
      imported: imported,
    }
    post("conversations/#{conversation_id}/notes", body: data)

    last_response.code == HTTP_CREATED
  end

  # Public: Create phone thread
  #
  # More info: https://developer.helpscout.com/mailbox-api/endpoints/conversations/threads/phone/
  def create_phone(conversation_id:, text:, customer:, imported: false)
    # Note, hs does not list user as an accepted type
    # https://developer.helpscout.com/mailbox-api/endpoints/conversations/threads/phone/
    data = {
      text: text,
      customer: {
        id: customer
      },
      imported: imported,
    }
    post("conversations/#{conversation_id}/phones", body: data)

    last_response.code == HTTP_CREATED
  end

  # Public: Create reply thread
  #
  # More info: https://developer.helpscout.com/mailbox-api/endpoints/conversations/threads/reply/
  def create_reply(conversation_id:, text:, customer:, user: nil, imported: false)
    data = {
      text: text,
      user: user,
      customer: {
        id: customer
      },
      imported: imported,
    }
    post("conversations/#{conversation_id}/reply", body: data)

    last_response.code == HTTP_CREATED
  end

  # Public: Get customer
  #
  # id - customer id
  #
  # More info: https://developer.helpscout.com/mailbox-api/endpoints/customers/get/
  def get_customer(id)
    get("customers/#{id}")
  end

  # Public: Update customer
  #
  # Note: to update address, chat handles, emails, phones, social profiles or
  # websites, separate endpoints have to be used.
  #
  # id - customer id
  # data - hash with data
  #
  # More info: https://developer.helpscout.com/mailbox-api/endpoints/customers/update/
  def update_customer(id, data)
    put("customers/#{id}", { body: data })
  end

  # Public: Create phone number
  #
  # More info: https://developer.helpscout.com/mailbox-api/endpoints/customers/phones/create/
  def create_customer_phone(customer_id, data)
    post("customers/#{customer_id}/phones", { body: data })
  end

  # Public: Delete phone number
  #
  # More info: https://developer.helpscout.com/mailbox-api/endpoints/customers/phones/delete/
  def delete_customer_phone(customer_id, phone_id)
    delete("customers/#{customer_id}/phones/#{phone_id}")
  end

  # Public: Create email
  #
  # More info: https://developer.helpscout.com/mailbox-api/endpoints/customers/emails/create/
  def create_customer_email(customer_id, data)
    post("customers/#{customer_id}/emails", { body: data })
  end

  # Public: Delete email
  #
  # More info: https://developer.helpscout.com/mailbox-api/endpoints/customers/emails/delete/
  def delete_customer_email(customer_id, email_id)
    delete("customers/#{customer_id}/emails/#{email_id}")
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

  def delete(path, options = {})
    request(:delete, path, options)
  end

  def patch(path, options = {})
    options[:body] = options[:body].to_json if options[:body]

    request(:patch, path, options)
  end

  def search(path, query, page_id = 1, items = [])
    options = { query: { page: page_id, query: "(#{query})" } }

    result = get(path, options)
    next_page_id = page_id + 1

    if result.key?("_embedded")
      items += result["_embedded"]["conversations"]
    end

    if next_page_id > result["page"]["totalPages"]
      return items
    else
      search(path, query, next_page_id, items)
    end
  end

  def request(method, path, options)
    uri = URI("https://api.helpscout.net/v2/#{path}")

    options = {
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer #{@token_storage.token}",
      }
    }.merge(options)
    puts "using token: #{@token_storage.token}"

    @last_response = HTTParty.send(method, uri, options)

    case last_response.code
    when HTTP_UNAUTHORIZED
      # Unauthorized means our token is expired. We will fetch a new one, and
      # retry the original request
      new_token = generate_oauth_token
      @token_storage.store_token(new_token)
      options.delete(:headers)
      request(method, path, options)
    when HTTP_OK, HTTP_CREATED, HTTP_NO_CONTENT
      last_response.parsed_response
    when HTTP_BAD_REQUEST
      body = JSON.parse(last_response.parsed_response)
      raise ValidationError, body["_embedded"]["errors"].to_json
    when HTTP_FORBIDDEN
      raise ForbiddenError
    when HTTP_NOT_FOUND
      raise NotFoundError
    when HTTP_INTERNAL_SERVER_ERROR
      error_message = JSON.parse(last_response.body)["error"]
      raise InternalServerError, error_message
    when HTTP_SERVICE_UNAVAILABLE
      raise ServiceUnavailable
    when HTTP_TOO_MANY_REQUESTS
      retry_after = last_response.headers["X-RateLimit-Retry-After"]
      message = "Rate limit of 200 RPM or 12 POST/PUT/DELETE requests per 5 " +
        "seconds reached. Next request possible in #{retry_after} seconds."
      raise TooManyRequestsError, message
    else
      raise NotImplementedError, "Help Scout returned something that is not implemented by the help_scout gem yet: #{last_response.code}: #{last_response.parsed_response["message"] if last_response.parsed_response}"
    end
  end
end
