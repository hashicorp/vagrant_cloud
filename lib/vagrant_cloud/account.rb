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
    # @param [Hash] params
    # @return [Box]
    def create_box(name, *args)
      params = box_params(*args)
      params[:name] = name

      data = request('post', '/boxes', {:box => params})
      get_box(name, data)
    end

    # @param [String] name
    # @param [Hash] params
    # @return [Box]
    def ensure_box(name, *args)
      params = box_params(*args)

      begin
        box = get_box(name)
        box.data
      rescue RestClient::ResourceNotFound => e
        box = create_box(name, params)
        # If we've just created the box, we're done.
        return box
      end

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

    # @param [Array] args
    # @return [Hash]
    def box_params(*args)
      # This dance is to simulate what we could have accomplished with **args
      # in Ruby 2.0+
      # Find and remove the first hash we find in *args. Set params to an
      # empty hash if we weren't passed one.
      # This could easily be changed to merge all hashes in *args if
      # necessary.
      params = args.select { |v| v.is_a?(Hash) }.first
      if params.nil?
        params = {}
      else
        args.delete_if { |v| v == params }
      end

      # Description should be the first item that's left in *args, if nothing
      # is left (we were only passed a hash), this will return nil.
      description = args.first

      # If description is provided, it will override the params entry.
      # This is provided for backwards compatibility.
      unless description.nil?
        params[:description] = description
        params[:short_description] = description
      end

      # Default boxes to public can be overridden by providing :is_private
      params[:is_private] = false unless defined? params[:is_private]

      params
    end

  end
end
