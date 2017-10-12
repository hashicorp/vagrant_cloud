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
      @data ||= account.request('get', provider_path)
    end

    # @param [String] url
    def update(url)
      params = { url: url }
      @data = account.request('put', provider_path, provider: params)
    end

    def delete
      account.request('delete', provider_path)
    end

    # @return [String]
    def upload_url
      account.request('get', "#{provider_path}/upload")['upload_path']
    end

    # @param [String] file_path
    def upload_file(file_path)
      url = upload_url
      payload = File.open(file_path, 'r')
      RestClient::Request.execute(
        method: :put,
        url: url,
        payload: payload,
        ssl_version: 'TLSv1'
      )
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

    def provider_path
      "/box/#{account.username}/#{box.name}/version/#{version.number}/provider/#{name}"
    end
  end
end
