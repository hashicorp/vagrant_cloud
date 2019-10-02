module VagrantCloud
  # VagrantCloud account
  class Account
    # @return [Client]
    attr_reader :client
    # @return [String] username of this account
    attr_reader :username
    # @return [Instrumentor::Collection] Instrumentor in use
    attr_reader :instrumentor

    # Create a new Account instance
    #
    # @param [String] access_token Authentication token
    # @param [Client] client Client to use for account
    # @param [String] custom_server Custom server URL for client
    # @param [Integer] retry_count Number of retries on idempotent requests
    # @param [Integer] retry_interval Number of seconds to wait between requests
    # @param [Instrumentor::Core] instrumentor Instrumentor to use
    # @return [Account]
    def initialize(access_token: nil, client: nil, custom_server: nil, retry_count: nil, retry_interval: nil, instrumentor: nil)
      raise ArgumentError, "Account accepts `access_token` or `client` but not both" if
        client && access_token
      raise TypeError, "Expected `#{Client.name}` but received `#{client.class.name}`" if
        client && !client.is_a?(Client)

      if client
        @client = client
      else
        @client = Client.new(
          access_token: access_token,
          url_base: custom_server,
          retry_count: retry_count,
          retry_interval: retry_interval,
          instrumentor: instrumentor
        )
      end
      setup!
    end

    # @return [Search]
    def searcher
      Search.new(account: self)
    end

    #---------------------------
    # Authentication API Helpers
    #---------------------------

    # Create a new access token
    # @param [String] password Remote password
    # @param [String] description Description of token
    # @param [String] code 2FA code
    # @return [Response::CreateToken]
    def create_token(password:, description: Data::Nil, code: Data::Nil)
      r = client.authentication_token_create(username: username,
        password: password, description: description, code: code)

      Response::CreateToken.new(
        token: r[:token],
        token_hash: r[:token_hash],
        created_at: r[:created_at],
        description: r[:description]
      )
    end

    # Delete the current token
    #
    # @return [self]
    def delete_token
      client.authentication_token_delete
      self
    end

    # Validate the current token
    #
    # @return [self]
    def validate_token
      client.request(path: "authenticate")
      self
    end

    # Request a 2FA code is sent
    #
    # @param [String] delivery_method Delivery method of 2FA
    # @param [String] password Account password
    # @return [Response]
    def request_2fa_code(delivery_method:, password:)
      r = client.authentication_request_2fa_code(username: username,
        password: password, delivery_method: delivery_method)
      Response::Request2FA.new(destination: r.dig(:two_factor, :obfuscated_destination))
    end

    # Fetch the requested organization
    #
    # @param [String] name Organization name
    # @return [Organization]
    def organization(name: nil)
      org_name = name || username
      r = client.organization_get(name: org_name)
      Organization.load(account: self, **r)
    end

    protected

    def setup!
      if client.access_token
        r = client.request(path: "authenticate")
        @username = r.dig(:user, :username)
      end
    end
  end
end
