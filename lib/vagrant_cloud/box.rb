module VagrantCloud
  class Box < Data::Mutable
    autoload :Provider, "vagrant_cloud/box/provider"
    autoload :Version, "vagrant_cloud/box/version"

    attr_reader :organization
    attr_required :name
    attr_optional :created_at, :updated_at, :tag, :short_description,
      :description_html, :description_markdown, :private, :downloads,
      :current_version, :versions, :description, :username

    attr_mutable :short_description, :description, :private, :versions

    # Create a new instance
    #
    # @return [Box]
    def initialize(organization:, **opts)
      @organization = organization
      @versions_loaded = false
      opts[:username] = organization.username
      super(opts)
      if opts[:versions] && !opts[:versions].empty?
        self.versions= Array(opts[:versions]).map do |version|
          Box::Version.load(box: self, **version)
        end
      end
      if opts[:current_version]
        clean(data: {current_version: Box::Version.
          load(box: self, **opts[:current_version])})
      end
      clean!
    end

    # Delete this box
    #
    # @return [nil]
    # @note This will delete the box, and all versions
    def delete
      if exist?
        organization.account.client.box_delete(
          username: username,
          name: name
        )
        b = organization.boxes.dup
        b.delete(self)
        organization.clean(data: {boxes: b})
      end
      nil
    end

    # Add a new version of this box
    #
    # @param [String] version Version number
    # @return [Version]
    def add_version(version)
      if versions.any? { |v| v.version == version }
        raise Error::BoxError::VersionExistsError,
          "Version #{version} already exists for box #{tag}"
      end
      v = Version.new(box: self, version: version)
      clean(data: {versions: versions + [v]})
      v
    end

    # Check if this instance is dirty
    #
    # @param [Boolean] deep Check nested instances
    # @return [Boolean] instance is dirty
    def dirty?(key=nil, deep: false)
      if key
        super(key)
      else
        d = super() || !exist?
        if deep && !d
          d = Array(plain_versions).any? { |v| v.dirty?(deep: true) }
        end
        d
      end
    end

    # @return [Boolean] box exists remotely
    def exist?
      !!created_at
    end

    # @return [Array<Version>]
    # @note This is used to allow versions information to be loaded
    # only when requested
    def versions_on_demand
      if !@versions_loaded
        if exist?
          r = self.organization.account.client.box_get(username: username, name: name)
          v = Array(r[:versions]).map do |version|
            Box::Version.load(box: self, **version)
          end
          clean(data: {versions: v + Array(plain_versions)})
        else
          clean(data: {versions: []})
        end
        @versions_loaded = true
      end
      plain_versions
    end
    alias_method :plain_versions, :versions
    alias_method :versions, :versions_on_demand

    # Save the box if any changes have been made
    #
    # @return [self]
    def save
      save_versions if dirty?(deep: true)
      save_box if dirty?
      self
    end

    protected

    # Save the box
    #
    # @return [self]
    def save_box
      req_args = {
        username: username,
        name: name,
        short_description: short_description,
        description: description,
        is_private: self.private
      }
      if exist?
        result = organization.account.client.box_update(**req_args)
      else
        result = organization.account.client.box_create(**req_args)
      end
      clean(data: result, ignores: [:current_version, :versions])
      self
    end

    # Save the versions if any require saving
    #
    # @return [self]
    def save_versions
      versions.map(&:save)
      self
    end
  end
end
