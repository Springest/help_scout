class HelpScout
  module TokenStorage
    class Default
      def token
        @token
      end

      def store_token(token)
        @token = token
      end
    end
  end
end
