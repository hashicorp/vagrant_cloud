module VagrantCloud
  class Client
    include Logger
    # Base Vagrant Cloud API URL
    DEFAULT_URL = 'https://vagrantcloud.com/api/v1'.freeze
    # Valid methods that can be retried
    IDEMPOTENT_METHODS = [:get, :head].freeze
    # Number or allowed retries
    IDEMPOTENT_RETRIES = 3
    # Number of seconds to wait between retries
    IDEMPOTENT_RETRY_INTERVAL = 2
    # Methods which require query parameters
    QUERY_PARAMS_METHODS = [:get, :head, :delete].freeze
    # Default instrumentor
    DEFAULT_INSTRUMENTOR = Instrumentor::Collection.new

    # @return [Instrumentor::Collection]
    def self.instrumentor
      DEFAULT_INSTRUMENTOR
    end

    # @return [String] Access token for Vagrant Cloud
    attr_reader :access_token
    # @return [String] Base request path
    attr_reader :path_base
    # @return [String] URL for initializing connection
    attr_reader :url_base
    # @return [Integer] Number of retries on idempotent requests
    attr_reader :retry_count
    # @return [Integer] Number of seconds to wait between requests
    attr_reader :retry_interval
    # @return [Instrumentor::Collection] Instrumentor in use
    attr_reader :instrumentor

    # Create a new Client instance
    #
    # @param [String] access_token Authentication token for API requests
    # @param [String] url_base URL used to make API requests
    # @param [Integer] retry_count Number of retries on idempotent requests
    # @param [Integer] retry_interval Number of seconds to wait between requests
    # @param [Instrumentor::Core] instrumentor Instrumentor to use
    # @return [Client]
    def initialize(access_token: nil, url_base: nil, retry_count: nil, retry_interval: nil, instrumentor: nil)
      url_base = DEFAULT_URL if url_base.nil?
      remote_url = URI.parse(url_base)
      @url_base = "#{remote_url.scheme}://#{remote_url.host}"
      @path_base = remote_url.path
      @access_token = access_token.dup.freeze if access_token
      if !@access_token && ENV["VAGRANT_CLOUD_TOKEN"]
        @access_token = ENV["VAGRANT_CLOUD_TOKEN"].dup.freeze
      end
      @retry_count = retry_count.nil? ? IDEMPOTENT_RETRIES : retry_count.to_i
      @retry_interval = retry_interval.nil? ? IDEMPOTENT_RETRY_INTERVAL : retry_interval.to_i
      @instrumentor = instrumentor.nil? ? Instrumentor::Collection.new : instrumentor
      headers = {}.tap do |h|
        h["Accept"] = "application/json"
        h["Authorization"] = "Bearer #{@access_token}" if @access_token
        h["Content-Type"] = "application/json"
      end
      @connection_lock = Mutex.new
      @connection = Excon.new(url_base,
        headers: headers,
        instrumentor: @instrumentor
      )
    end

    # Use the remote connection
    #
    # @param [Boolean] wait Wait for the connection to be available
    # @yieldparam [Excon::Connection]
    # @return [Object]
    def with_connection(wait: true)
      raise ArgumentError,
        "Block expected but no block given" if !block_given?
      if !wait
        raise Error::ClientError::ConnectionLockedError,
          "Connection is currently locked" if !@connection_lock.try_lock
        begin
          yield @connection
        ensure
          @connection_lock.unlock
        end
      else
        @connection_lock.synchronize { yield @connection }
      end
    end

    # Send a request
    # @param [String, Symbol] method Request method
    # @param [String, URI] path Path of request
    # @param [Hash] params Parameters to send with request
    # @return [Hash]
    def request(path:, method: :get, params: {})
      if !path.start_with?(path_base)
        # Build the full path for the request and clean it
        path = [path_base, path].compact.join("/").gsub(/\/{2,}/, "/")
      end
      method = method.to_s.downcase.to_sym

      # Build base request parameters
      request_params = {
        method: method,
        path: path,
        expects: [200, 201, 204]
      }

      # If this is an idempotent request allow it to retry on failure
      if IDEMPOTENT_METHODS.include?(method)
        request_params[:idempotent] = true
        request_params[:retry_limit] = retry_count
        request_params[:retry_interval] = retry_interval
      end

      # If parameters are provided, set them in the expected location
      if !params.empty?
        # Copy the parameters so we can freely modify them
        params = clean_parameters(params)

        if QUERY_PARAMS_METHODS.include?(method)
          request_params[:query] = params
        else
          request_params[:body] = JSON.dump(params)
        end
      end

      # Set a request ID so we can track request/responses
      request_params[:headers] = {"X-Request-Id" => SecureRandom.uuid}

      begin
        result = with_connection { |c| c.request(request_params) }
      rescue Excon::Error::HTTPStatus => err
        raise Error::ClientError::RequestError.new(
              "Vagrant Cloud request failed", err.response.body, err.response.status)
      rescue Excon::Error => err
        raise Error::ClientError, err.message
      end

      parse_json(result.body)
    end

    # Clone this client to create a new instance
    #
    # @param [String] access_token Authentication token for API requests
    # @return [Client]
    def clone(access_token: nil)
      self.class.new(access_token: access_token, url_base: url_base,
        retry_count: retry_count, retry_interval: retry_interval
      )
    end

    # Submit a search on Vagrant Cloud
    #
    # @param [String] query Search query
    # @param [String] provider Limit results to only this provider
    # @param [String] sort Field to sort results ("downloads", "created", or "updated")
    # @param [String] order Order to return sorted result ("desc" or "asc")
    # @param [Integer] limit Number of results to return
    # @param [Integer] page Page number of results to return
    # @return [Hash]
    def search(query: Data::Nil, provider: Data::Nil, sort: Data::Nil, order: Data::Nil, limit: Data::Nil, page: Data::Nil)
      params = {
        q: query,
        provider: provider,
        sort: sort,
        order: order,
        limit: limit,
        page: page
      }
      request(method: :get, path: "search", params: params)
    end

    # Create a new access token
    #
    # @param [String] username Vagrant Cloud username
    # @param [String] password Vagrant Cloud password
    # @param [String] description Description of token
    # @param [String] code 2FA code
    # @return [Hash]
    def authentication_token_create(username:, password:, description: Data::Nil, code: Data::Nil)
      params = {
        user: {
          login: username,
          password: password
        },
        token: {
          description: description
        },
        two_factor: {
          code: code
        }
      }
      request(method: :post, path: "authenticate", params: params)
    end

    # Delete the token currently in use
    #
    # @return [Hash] empty
    def authentication_token_delete
      request(method: :delete, path: "authenticate")
    end

    # Request a 2FA code is sent
    #
    # @param [String] username Vagrant Cloud username
    # @param [String] password Vagrant Cloud password
    # @param [String] delivery_method Delivery method of 2FA
    # @param [String] password Account password
    # @return [Hash]
    def authentication_request_2fa_code(username:, password:, delivery_method:)
      params = {
        two_factor: {
          delivery_method: delivery_method
        },
        user: {
          login: username,
          password: password
        }
      }

      request(method: :post, path: "two-factor/request-code", params: params)
    end

    # Validate the current token
    #
    # @return [Hash] emtpy
    def authentication_token_validate
      request(method: :get, path: "authenticate")
    end

    # Get an organization
    #
    # @param [String] name Name of organization
    # @return [Hash] organization information
    def organization_get(name:)
      request(method: :get, path: "user/#{name}")
    end

    # Get an existing box
    #
    # @param [String] username Username/organization name to create box under
    # @param [String] name Box name
    # @return [Hash] box information
    def box_get(username:, name:)
      request(method: :get, path: "/box/#{username}/#{name}")
    end

    # Create a new box
    #
    # @param [String] username Username/organization name to create box under
    # @param [String] name Box name
    # @param [String] short_description Short description of box
    # @param [String] description Long description of box (markdown supported)
    # @param [Boolean] is_private Set if box is private
    # @return [Hash] box information
    def box_create(username:, name:, short_description: Data::Nil, description: Data::Nil, is_private: Data::Nil)
      request(method: :post, path: '/boxes', params: {
        username: username,
        name: name,
        short_description: short_description,
        description: description,
        is_private: is_private
      })
    end

    # Update an existing box
    #
    # @param [String] username Username/organization name to create box under
    # @param [String] name Box name
    # @param [String] short_description Short description of box
    # @param [String] description Long description of box (markdown supported)
    # @param [Boolean] is_private Set if box is private
    # @return [Hash] box information
    def box_update(username:, name:, short_description: Data::Nil, description: Data::Nil, is_private: Data::Nil)
      params = {
        short_description: short_description,
        description: description,
        is_private: is_private
      }
      request(method: :put, path: "/box/#{username}/#{name}", params: params)
    end

    # Delete an existing box
    #
    # @param [String] username Username/organization name to create box under
    # @param [String] name Box name
    # @return [Hash] box information
    def box_delete(username:, name:)
      request(method: :delete, path: "/box/#{username}/#{name}")
    end

    # Get an existing box version
    #
    # @param [String] username Username/organization name to create box under
    # @param [String] name Box name
    # @param [String] version Box version
    # @return [Hash] box version information
    def box_version_get(username:, name:, version:)
      request(method: :get, path: "/box/#{username}/#{name}/version/#{version}")
    end

    # Create a new box version
    #
    # @param [String] username Username/organization name to create box under
    # @param [String] name Box name
    # @param [String] version Box version
    # @param [String] description Box description
    # @return [Hash] box version information
    def box_version_create(username:, name:, version:, description: Data::Nil)
      request(method: :post, path: "/box/#{username}/#{name}/versions", params: {
        version: {
          version: version,
          description: description
        }
      })
    end

    # Update an existing box version
    #
    # @param [String] username Username/organization name to create box under
    # @param [String] name Box name
    # @param [String] version Box version
    # @param [String] description Box description
    # @return [Hash] box version information
    def box_version_update(username:, name:, version:, description: Data::Nil)
      params = {
        version: {
          version: version,
          description: description
        }
      }
      request(method: :put, path: "/box/#{username}/#{name}/version/#{version}", params: params)
    end

    # Delete an existing box version
    #
    # @param [String] username Username/organization name to create box under
    # @param [String] name Box name
    # @param [String] version Box version
    # @return [Hash] box version information
    def box_version_delete(username:, name:, version:)
      request(method: :delete, path: "/box/#{username}/#{name}/version/#{version}")
    end

    # Release an existing box version
    #
    # @param [String] username Username/organization name to create box under
    # @param [String] name Box name
    # @param [String] version Box version
    # @return [Hash] box version information
    def box_version_release(username:, name:, version:)
      request(method: :put, path: "/box/#{username}/#{name}/version/#{version}/release")
    end

    # Revoke an existing box version
    #
    # @param [String] username Username/organization name to create box under
    # @param [String] name Box name
    # @param [String] version Box version
    # @return [Hash] box version information
    def box_version_revoke(username:, name:, version:)
      request(method: :put, path: "/box/#{username}/#{name}/version/#{version}/revoke")
    end

    # Get an existing box version provider
    #
    # @param [String] username Username/organization name to create box under
    # @param [String] name Box name
    # @param [String] version Box version
    # @param [String] provider Provider name
    # @return [Hash] box version provider information
    def box_version_provider_get(username:, name:, version:, provider:)
      request(method: :get, path: "/box/#{username}/#{name}/version/#{version}/provider/#{provider}")
    end

    # Create a new box version provider
    #
    # @param [String] username Username/organization name to create box under
    # @param [String] name Box name
    # @param [String] version Box version
    # @param [String] provider Provider name
    # @param [String] url Remote URL for box download
    # @return [Hash] box version provider information
    def box_version_provider_create(username:, name:, version:, provider:, url: Data::Nil, checksum: Data::Nil, checksum_type: Data::Nil)
      request(method: :post, path: "/box/#{username}/#{name}/version/#{version}/providers", params: {
        provider: {
          name: provider,
          url: url,
          checksum: checksum,
          checksum_type: checksum_type
        }
      })
    end

    # Update an existing box version provider
    #
    # @param [String] username Username/organization name to create box under
    # @param [String] name Box name
    # @param [String] version Box version
    # @param [String] provider Provider name
    # @param [String] url Remote URL for box download
    # @return [Hash] box version provider information
    def box_version_provider_update(username:, name:, version:, provider:, url: Data::Nil, checksum: Data::Nil, checksum_type: Data::Nil)
      params = {
        provider: {
          name: provider,
          url: url,
          checksum: checksum,
          checksum_type: checksum_type
        }
      }
      request(method: :put, path: "/box/#{username}/#{name}/version/#{version}/provider/#{provider}", params: params)
    end

    # Delete an existing box version provider
    #
    # @param [String] username Username/organization name to create box under
    # @param [String] name Box name
    # @param [String] version Box version
    # @param [String] provider Provider name
    # @return [Hash] box version provider information
    def box_version_provider_delete(username:, name:, version:, provider:)
      request(method: :delete, path: "/box/#{username}/#{name}/version/#{version}/provider/#{provider}")
    end

    # Upload a box asset for an existing box version provider
    #
    # @param [String] username Username/organization name to create box under
    # @param [String] name Box name
    # @param [String] version Box version
    # @param [String] provider Provider name
    # @return [Hash] box version provider upload information (contains upload_path entry)
    def box_version_provider_upload(username:, name:, version:, provider:)
      request(method: :get, path: "/box/#{username}/#{name}/version/#{version}/provider/#{provider}/upload")
    end

    # Upload a box asset directly to the backend storage for an existing box version provider
    #
    # @param [String] username Username/organization name to create box under
    # @param [String] name Box name
    # @param [String] version Box version
    # @param [String] provider Provider name
    # @return [Hash] box version provider upload information (contains upload_path and callback entries)
    def box_version_provider_upload_direct(username:, name:, version:, provider:)
      request(method: :get, path: "/box/#{username}/#{name}/version/#{version}/provider/#{provider}/upload/direct")
    end

    protected

    # Parse a string of JSON
    #
    # @param [String] string String of JSON data
    # @return [Object]
    # @note All keys are symbolized when parsed
    def parse_json(string)
      return {} if string.empty?
      JSON.parse(string, symbolize_names: true)
    end

    # Remove any values that have a default value set
    #
    # @param [Object] item Item to clean
    # @return [Object] cleaned item
    def clean_parameters(item)
      case item
      when Array
        item = item.find_all { |i| i != Data::Nil }
        item.map! { |i| clean_parameters(i) }
      when Hash
        item = item.dup
        item.delete_if{ |_,v| v == Data::Nil }
        item.keys.each do |k|
          item[k] = clean_parameters(item[k])
        end
      end
      item
    end
  end
end
