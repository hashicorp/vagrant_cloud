module VagrantCloud

  class Version

    attr_accessor :box
    attr_accessor :number
    attr_accessor :data

    def initialize(box, number, data = nil)
      @box = box
      @number = number
      @data = data
    end

    def version
      data['version']
    end

    def description
      data['description_markdown']
    end

    def providers
      data['providers'].map { |data| Provider.new(self, data['name'], data) }
    end

    def data
      @data ||= account.request('get', "/box/#{account.username}/#{box.name}/version/#{number}")
    end

    def update(description)
      version = {:description => description}
      @data = account.request('put', "/box/#{account.username}/#{box.name}/version/#{number}", {:version => version})
    end

    def delete
      account.request('delete', "/box/#{account.username}/#{box.name}/version/#{number}")
    end

    def release
      @data = account.request('put', "/box/#{account.username}/#{box.name}/version/#{number}/release")
    end

    def revoke
      @data = account.request('put', "/box/#{account.username}/#{box.name}/version/#{number}/revoke")
    end

    def get_provider(name, data = nil)
      Provider.new(self, name, data)
    end

    def create_provider(name, url)
      params = {:name => name, :url => url}
      data = account.request('post', "/box/#{account.username}/#{box.name}/version/#{self.number}/providers", {:provider => params})
      get_provider(name, data)
    end

    def ensure_provider(name, url)
      provider = providers.select{ |provider| provider.name == name }.first
      unless provider
        provider = create_provider(name, url)
      end
      if url != provider.url
        provider.update(url)
      end
      provider
    end

    private

    def account
      box.account
    end

  end
end
