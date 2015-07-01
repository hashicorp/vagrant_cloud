module VagrantCloud

  class Account

    attr_accessor :username
    attr_accessor :access_token

    # @param [String] username
    # @param [String] access_token
    def initialize(username, access_token)
      @username = username
      @access_token = access_token
    end

    # @param [String] name
    # @param [Hash]
    # @return [Box]
    def get_box(name, data = nil)
      Box.new(self, name, data)
    end

    # @param [String] name
    # @param [String] description
    # @param [Hash] params
    # @return [Box]
    def create_box(name, description = nil, **params)
      fail "Parameters must be a hash" unless params.is_a?(Hash)
      params[:name] = name

      # If description is provided, it will override the params entry.
      # This is provided for backwards compatibility.
      params[:description] = description unless description.nil?
      params[:short_description] = description unless description.nil?

      # Default boxes to public can be overridden by providing :is_private
      params[:is_private] = false unless defined? params[:is_private]

      data = request('post', '/boxes', {:box => params})
      get_box(name, data)
    end

    # @param [String] name
    # @param [String] description
    # @param [Hash] params
    # @return [Box]
    def ensure_box(name, description = nil, **params)
      fail "Parameters must be a hash" unless params.is_a?(Hash)

      # If description is provided, it will override the params entry.
      # This is provided for backwards compatibility.
      unless description.nil?
        params[:description] = description
        params[:short_description] = description
      end

      begin
        box = get_box(name)
        box.data
      rescue RestClient::ResourceNotFound => e
        box = create_box(name, params)
        # If we've just created the box, we're done.
        return box
      end

      # If params is empty, there's nothing to update.
      return box if params.empty?

      # Select elements from params that don't match what we have in the box
      # data. These are changed parameters and should be updated.
      update_params = params.select { |k,v|
        box.data[box.param_name(k)] != v
      }

      # Update the box with any params that had changed.
      box.update(update_params) unless update_params.empty?

      box
    end

    # @param [String] method
    # @param [String] path
    # @param [Hash] params
    # @return [Hash]
    def request(method, path, params = {})
      params[:access_token] = access_token
      result = RestClient::Request.execute(
        :method => method,
        :url => url_base + path,
        :payload => params,
        :ssl_version => 'TLSv1'
      )
      result = JSON.parse(result)
      errors = result['errors']
      raise(RuntimeError, "Vagrant Cloud returned error: #{errors}") if errors
      result
    end

    private

    # @return [String]
    def url_base
      'https://vagrantcloud.com/api/v1'
    end

  end
end
