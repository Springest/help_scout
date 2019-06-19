class HelpScout
  module TokenStorage
    class Redis
      IDENTIFIER = "helpscout-client-token"

      def initialize(db)
        @db = db
      end

      def token
        @db.get(IDENTIFIER)
      end

      def store_token(new_token)
        @db.set(IDENTIFIER, new_token)
      end
    end
  end
end
