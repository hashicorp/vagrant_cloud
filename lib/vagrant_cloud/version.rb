module VagrantCloud
  class Version
    attr_accessor :box
    attr_accessor :number
    attr_accessor :data

    # @param [Box] box
    # @param [String] number
    # @param [Hash] data
    def initialize(box, number, data = nil)
      @box = box
      @number = number
      @data = data
    end

    # @return [String]
    def version
      data['version'].to_s
    end

    # @return [String]
    def description
      data['description_markdown'].to_s
    end

    # @return [String]
    def status
      data['status'].to_s
    end

    # @return [Array<Provider>]
    def providers
      data['providers'].map { |data| Provider.new(self, data['name'], data) }
    end

    # @return [String]
    def to_s
      version
    end

    # @return [Hash]
    def data
      @data ||= account.request('get', "/box/#{account.username}/#{box.name}/version/#{number}")
    end

    # @param [String] description
    def update(description)
      version = { description: description }
      @data = account.request('put', "/box/#{account.username}/#{box.name}/version/#{number}", version: version)
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

    # @param [String] name
    # @param [Hash] data
    # @return [Provider]
    def get_provider(name, data = nil)
      Provider.new(self, name, data)
    end

    # @param [String] name
    # @param [String] url
    # @return [Provider]
    def create_provider(name, url = nil)
      params = { name: name, url: url }.delete_if { |_k, v| v.nil? }
      data = account.request('post', "/box/#{account.username}/#{box.name}/version/#{number}/providers", provider: params)
      get_provider(name, data)
    end

    # @param [String] name
    # @param [String] url
    # @return [Provider]
    def ensure_provider(name, url)
      provider = providers.select { |provider| provider.name == name }.first
      provider = create_provider(name, url) unless provider
      provider.update(url) if url != provider.url
      provider
    end

    private

    # @return [Account]
    def account
      box.account
    end
  end
end
