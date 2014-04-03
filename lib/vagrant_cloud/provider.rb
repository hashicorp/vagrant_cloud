module VagrantCloud

  class Provider

    attr_accessor :version
    attr_accessor :name
    attr_accessor :data

    def initialize(version, name, data = nil)
      @version = version
      @name = name
      @data = data
    end

    def url
      data['original_url']
    end

    def download_url
      data['download_url']
    end

    def data
      @data ||= account.request('get', "/box/#{account.username}/#{box.name}/version/#{version.number}/provider/#{name}")
    end

    def update(url)
      params = {:url => url}
      @data = account.request('put', "/box/#{account.username}/#{box.name}/version/#{version.number}/provider/#{name}", {:provider => params})
    end

    def delete
      account.request('delete', "/box/#{account.username}/#{box.name}/version/#{version.number}/provider/#{name}")
    end

    private

    def box
      version.box
    end

    def account
      box.account
    end

  end
end
