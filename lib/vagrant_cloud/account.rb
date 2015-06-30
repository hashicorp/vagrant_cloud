module VagrantCloud

  class Account

    attr_accessor :username
    attr_accessor :access_token

    def initialize(username, access_token)
      @username = username
      @access_token = access_token
    end

    def get_box(name, data = nil)
      Box.new(self, name, data)
    end

    def create_box(name, description = nil, is_private = false)
      params = {:name => name}
      params[:description] = description if description
      params[:short_description] = description if description
      params[:is_private] = is_private
      data = request('post', '/boxes', {:box => params})
      get_box(name, data)
    end

    def ensure_box(name, description = nil, is_private = false)
      begin
        box = get_box(name)
        box.data
      rescue RestClient::ResourceNotFound => e
        box = create_box(name, description, is_private)
      end
      if description and (description != box.description || description != box.description_short)
        box.update(description)
      end
      box
    end

    def request(method, path, params = {})
      params[:access_token] = access_token
      headers = {:access_token => access_token}
      result = RestClient::Request.execute(
          :method => method,
          :url => url_base + path,
          :payload => params,
          :headers => headers,
          :ssl_version => 'TLSv1'
      )
      result = JSON.parse(result)
      errors = result['errors']
      raise "Vagrant Cloud returned error: #{errors}" if errors
      result
    end

    private

    def url_base
      'https://vagrantcloud.com/api/v1'
    end

  end
end
