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

    def create_box(name, description = nil)
      params = {:name => name}
      params[:description] = description if description
      params[:short_description] = description if description
      data = request('post', '/boxes', {:box => params})
      get_box(name, data)
    end

    def ensure_box(name, description = nil)
      begin
        box = get_box(name)
        box.data
      rescue RestClient::ResourceNotFound => e
        box = create_box(name, description)
      end
      if description and (description != box.description || description != box.description_short)
        box.update(description)
      end
      box
    end

    def request(method, path, params = {})
      params[:access_token] = access_token
      arg = {:params => params}
      arg = params if ['post', 'put'].include? method # Weird rest_client api
      result = RestClient.send(method, url_base + path, arg)
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
