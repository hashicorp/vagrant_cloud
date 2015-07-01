module VagrantCloud

  class Box

    attr_accessor :account
    attr_accessor :name
    attr_accessor :data

    def initialize(account, name, data = nil)
      @account = account
      @name = name
      @data = data
    end

    def description
      data['description_markdown']
    end

    def description_short
      data['short_description']
    end

    def private
      data['private']
    end

    def versions
      version_list = data['versions'].map { |data| VagrantCloud::Version.new(self, data['number'], data) }
      version_list.sort_by { |version| Gem::Version.new(version.number) }
    end

    def data
      @data ||= account.request('get', "/box/#{account.username}/#{name}")
    end

    def update(description, is_private)
      box = {
        :short_description => description,
        :description => description,
        :is_private => is_private,
      }
      @data = account.request('put', "/box/#{account.username}/#{name}", {:box => box})
    end

    def delete
      account.request('delete', "/box/#{account.username}/#{name}")
    end

    def get_version(number, data = nil)
      VagrantCloud::Version.new(self, number, data)
    end

    def create_version(name, description = nil)
      params = {:version => name}
      params[:description] = description if description
      data = account.request('post', "/box/#{account.username}/#{self.name}/versions", {:version => params})
      get_version(data['number'], data)
    end

    def ensure_version(name, description = nil)
      version = versions.select { |version| version.version == name }.first
      unless version
        version = create_version(name, description)
      end
      if description and (description != version.description)
        version.update(description)
      end
      version
    end

  end
end
