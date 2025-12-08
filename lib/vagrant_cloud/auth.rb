# Copyright IBM Corp. 2014, 2025
# SPDX-License-Identifier: MIT

require "oauth2"

module VagrantCloud
  class Auth

    # Default authentication URL
    DEFAULT_AUTH_URL = "https://auth.idp.hashicorp.com".freeze
    # Default authorize path
    DEFAULT_AUTH_PATH = "/oauth2/auth".freeze
    # Default token path
    DEFAULT_TOKEN_PATH = "/oauth2/token".freeze
    # Number of seconds to pad token expiry
    TOKEN_EXPIRY_PADDING = 5

    # HCP configuration for generating authentication tokens
    #
    # @param [String] client_id Service principal client ID
    # @param [String] client_secret Service principal client secret
    # @param [String] auth_url Authentication URL end point
    # @param [String] auth_path Authorization path (relative to end point)
    # @param [String] token_path Token path (relative to end point)
    HCPConfig = Struct.new(:client_id, :client_secret, :auth_url, :auth_path, :token_path, keyword_init: true) do
      # Raise exception if any values are missing
      def validate!
        [:client_id, :client_secret, :auth_url, :auth_path, :token_path].each do |name|
          raise ArgumentError,
            "Missing required HCP authentication configuration value: HCP_#{name.to_s.upcase}" if self.send(name).to_s.empty?
        end
      end
    end

    # HCP token
    #
    # @param [String] token HCP token value
    # @param [Integer] expires_at Epoch seconds
    HCPToken = Struct.new(:token, :expires_at, keyword_init: true) do
      # Raise exception if any values are missing
      def validate!
        [:token, :expires_at].each do |name|
          raise ArgumentError,
            "Missing required token value - #{name.inspect}" if self.send(name).nil?
        end
      end

      # @return [Boolean] token is expired
      # @note Will show token as expired TOKEN_EXPIRY_PADDING
      # seconds prior to actual expiry
      def expired?
        validate!

        Time.now.to_i > (expires_at - TOKEN_EXPIRY_PADDING)
      end

      # @return [Boolean] token is not expired
      def valid?
        !expired?
      end
    end

    # Create a new auth instance
    #
    # @param [String] access_token Static access token
    # @note If no access token is provided, the token will be extracted
    # from the VAGRANT_CLOUD_TOKEN environment variable. If that value
    # is not set, the HCP_CLIENT_ID and HCP_CLIENT_SECRET environment
    # variables will be checked. If found, tokens will be generated as
    # needed using the client id and secret. Otherwise, no token will
    # will be available.
    def initialize(access_token: nil)
      @token = access_token

      # The Vagrant Cloud token has precedence over
      # anything else, so if it is set then it is
      # the only value used.
      @token = ENV["VAGRANT_CLOUD_TOKEN"] if @token.nil?

      # If there is no token set, attempt to load HCP configuration
      if @token.to_s.empty? && (ENV["HCP_CLIENT_ID"] || ENV["HCP_CLIENT_SECRET"])
        @config = HCPConfig.new(
          client_id: ENV["HCP_CLIENT_ID"],
          client_secret: ENV["HCP_CLIENT_SECRET"],
          auth_url: ENV.fetch("HCP_AUTH_URL", DEFAULT_AUTH_URL),
          auth_path: ENV.fetch("HCP_AUTH_PATH", DEFAULT_AUTH_PATH),
          token_path: ENV.fetch("HCP_TOKEN_PATH", DEFAULT_TOKEN_PATH)
        )

        # Validate configuration is populated
        @config.validate!
      end
    end

    # @return [String] authentication token
    def token
      # If a static token is defined, use that value
      return @token if @token

      # If no configuration is set, there is no auth to provide
      return if @config.nil?

      # If an HCP token exists and is not expired
      return @hcp_token.token if @hcp_token&.valid?

      # Generate a new HCP token
      refresh_token!

      @hcp_token.token
    end

    # @return [Boolean] Authentication token is available
    def available?
      !!(@token || @config)
    end

    private

    # Refresh the HCP oauth2 token.
    # @todo rescue exceptions and make them nicer
    def refresh_token!
      client = OAuth2::Client.new(
        @config.client_id,
        @config.client_secret,
        site: @config.auth_url,
        authorize_url: @config.auth_path,
        token_url: @config.token_path,
      )

      begin
        response = client.client_credentials.get_token
        @hcp_token = HCPToken.new(
          token: response.token,
          expires_at: response.expires_at,
        )
      rescue OAuth2::Error => err
        raise Error::ClientError::AuthenticationError,
          err.response.body.chomp,
          err.response.status
      end
    end
  end
end
