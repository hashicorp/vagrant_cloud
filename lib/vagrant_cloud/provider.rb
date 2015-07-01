module VagrantCloud

  class Provider

    attr_accessor :version
    attr_accessor :name
    attr_accessor :data

    # @param [Version] version
    # @param [String] name
    # @param [Hash] data
    def initialize(version, name, data = nil)
      @version = version
      @name = name
      @data = data
    end

    # @return [String]
    def url
      data['original_url'].to_s
    end

    # @return [String]
    def download_url
      data['download_url'].to_s
    end

    # @return [Hash]
    def data
      @data ||= account.request('get', "/box/#{account.username}/#{box.name}/version/#{version.number}/provider/#{name}")
    end

    # @param [String] url
    def update(url)
      params = {:url => url}
      @data = account.request('put', "/box/#{account.username}/#{box.name}/version/#{version.number}/provider/#{name}", {:provider => params})
    end

    def delete
      account.request('delete', "/box/#{account.username}/#{box.name}/version/#{version.number}/provider/#{name}")
    end

    private

    # @return [Box]
    def box
      version.box
    end

    # @return [Account]
    def account
      box.account
    end

  end
end
