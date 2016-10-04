module VagrantCloud
  class Box
    attr_accessor :account
    attr_accessor :name
    attr_accessor :data

    # @param [String] account
    # @param [String] name
    # @param [Hash] data
    def initialize(account, name, data = nil)
      @account = account
      @name = name
      @data = data
    end

    # @return [String]
    def description
      data['description_markdown'].to_s
    end

    # @return [String]
    def description_short
      data['short_description'].to_s
    end

    # @return [TrueClass, FalseClass]
    def private
      !!data['private']
    end

    # @return [Array<Version>]
    def versions
      version_list = data['versions'].map { |data| VagrantCloud::Version.new(self, data['number'], data) }
      version_list.sort_by { |version| Gem::Version.new(version.number) }
    end

    # @return [Hash]
    def data
      @data ||= account.request('get', "/box/#{account.username}/#{name}")
    end

    # @param [Hash] args
    def update(args = {})
      @data = account.request('put', "/box/#{account.username}/#{name}", box: args)
    end

    def delete
      account.request('delete', "/box/#{account.username}/#{name}")
    end

    # @param [Integer] number
    # @param [Hash] data
    # @return [Version]
    def get_version(number, data = nil)
      VagrantCloud::Version.new(self, number, data)
    end

    # @param [String] name
    # @param [String] description
    # @return [Version]
    def create_version(name, description = nil)
      params = { version: name }
      params[:description] = description if description
      data = account.request('post', "/box/#{account.username}/#{self.name}/versions", version: params)
      get_version(data['number'], data)
    end

    # @param [String] name
    # @param [String] description
    # @return [Version]
    def ensure_version(name, description = nil)
      version = versions.select { |version| version.version == name }.first
      version = create_version(name, description) unless version
      if description && (description != version.description)
        version.update(description)
      end
      version
    end

    # @param [Symbol]
    # @return [String]
    def param_name(param)
      # This needs to return strings, otherwise it won't match the JSON that
      # Vagrant Cloud returns.
      ATTR_MAP.fetch(param, param.to_s)
    end

    private

    # Vagrant Cloud returns keys different from what you set for some params.
    # Values in this map should be strings.
    ATTR_MAP = {
      is_private: 'private',
      description: 'description_markdown'
    }.freeze
  end
end
