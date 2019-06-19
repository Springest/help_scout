class HelpScout
  module TokenStorage
    class Memory
      def token
        @token
      end

      def store_token(token)
        @token = token
      end
    end
  end
end
