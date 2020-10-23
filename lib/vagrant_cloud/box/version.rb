module VagrantCloud
  class Box
    class Version < Data::Mutable
      attr_reader :box
      attr_required :version
      attr_optional :status, :description_html, :description_markdown,
        :created_at, :updated_at, :number, :providers, :description

      attr_mutable :description

      def initialize(box:, **opts)
        if !box.is_a?(Box)
          raise TypeError, "Expecting type `#{Box.name}` but received `#{box.class.name}`"
        end
        @box = box
        opts[:providers] = Array(opts[:providers]).map do |provider|
          if provider.is_a?(Provider)
            provider
          else
            Provider.load(version: self, **provider)
          end
        end
        super(opts)
        clean!
      end

      # Delete this version
      #
      # @return [nil]
      # @note This will delete the version, and all providers
      def delete
        if exist?
          box.organization.account.client.box_version_delete(
            username: box.username,
            name: box.name,
            version: version
          )
          # Remove self from box
          v = box.versions.dup
          v.delete(self)
          box.clean(data: {versions: v})
        end
        nil
      end

      # Release this version
      #
      # @return [self]
      def release
        if released?
          raise Error::BoxError::VersionStatusChangeError,
            "Version #{version} is already released for box #{box.tag}"
        end
        if !exist?
          raise Error::BoxError::VersionStatusChangeError,
            "Version #{version} for box #{box.tag} must be saved before release"
        end
        result = box.organization.account.client.box_version_release(
          username: box.username,
          name: box.name,
          version: version
        )
        clean(data: result, only: :status)
        self
      end

      # Revoke this version
      #
      # @return [self]
      def revoke
        if !released?
          raise Error::BoxError::VersionStatusChangeError,
            "Version #{version} is not yet released for box #{box.tag}"
        end
        result = box.organization.account.client.box_version_revoke(
          username: box.username,
          name: box.name,
          version: version
        )
        clean(data: result, only: :status)
        self
      end

      # @return [Boolean]
      def released?
        status == "active"
      end

      # Add a new provider for this version
      #
      # @param [String] pname Name of provider
      # @return [Provider]
      def add_provider(pname)
        if providers.any? { |p| p.name == pname }
          raise Error::BoxError::VersionProviderExistsError,
            "Provider #{pname} already exists for box #{box.tag} version #{version}"
        end
        pv = Provider.new(version: self, name: pname)
        clean(data: {providers: providers + [pv]})
        pv
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
            d = providers.any? { |p| p.dirty?(deep: true) }
          end
          d
        end
      end

      # @return [Boolean] version exists remotely
      def exist?
        !!created_at
      end

      # Save the version if any changes have been made
      #
      # @return [self]
      def save
        save_version if dirty?
        save_providers if dirty?(deep: true)
        self
      end

      protected

      # Save the version
      #
      # @return [self]
      def save_version
        params = {
          username: box.username,
          name: box.name,
          version: version,
          description: description
        }
        if exist?
          result = box.organization.account.client.box_version_update(**params)
        else
          result = box.organization.account.client.box_version_create(**params)
        end
        clean(data: result, ignores: :providers)
        self
      end

      # Save the providers if any require saving
      #
      # @return [self]
      def save_providers
        Array(providers).map(&:save)
        self
      end
    end
  end
end
