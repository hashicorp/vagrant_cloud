module VagrantCloud
  class Box
    class Provider < Data::Mutable
      attr_reader :version
      attr_required :name
      attr_optional :hosted, :created_at, :updated_at,
        :checksum, :checksum_type, :original_url, :download_url,
        :url

      attr_mutable :url, :checksum, :checksum_type

      def initialize(version:, **opts)
        if !version.is_a?(Version)
          raise TypeError, "Expecting type `#{Version.name}` but received `#{version.class.name}`"
        end
        @version = version
        super(**opts)
      end

      # Delete this provider
      #
      # @return [nil]
      def delete
        if exist?
          version.box.organization.account.client.box_version_provider_delete(
            username: version.box.username,
            name: version.box.name,
            version: version.version,
            provider: name
          )
          version.providers.delete(self)
        end
        nil
      end

      # Upload box file to be hosted on VagrantCloud. If
      # path is provided, file will be uploaded. If block
      # is given, the URL to upload the asset will be provided.
      # If a path is not provided, and a block is not provided,
      # the URL to upload the asset will be returned.
      #
      # @param [String] path Path to asset
      # @yieldparam [String] url URL to upload asset
      # @return [self, Object, String] self when path provided, result of yield when block provided, URL otherwise
      def upload(path: nil)
        if !exist?
          raise Error::BoxError::ProviderNotFoundError,
            "Provider #{name} not found for box #{version.box.tag} version #{version.version}"
        end
        if path && block_given?
          raise ArgumentError,
            "Only path or block may be provided, not both"
        end
        if path && !File.exist?(path)
          raise Errno::ENOENT, path
        end
        result = version.box.organization.account.client.box_version_provider_upload(
          username: version.box.username,
          name: version.box.name,
          version: version.version,
          provider: name
        )
        url = result[:upload_path]
        if block_given?
          yield url
        elsif path
          File.open(path, "rb") do |file|
            chunks = lambda { file.read(Excon.defaults[:chunk_size]).to_s }
            Excon.put(url, request_block: chunks)
          end
          self
        else
          url
        end
      end

      # @return [Boolean] provider exists remotely
      def exist?
        !!created_at
      end

      # Check if this instance is dirty
      #
      # @param [Boolean] deep Check nested instances
      # @return [Boolean] instance is dirty
      def dirty?(key=nil, **args)
        if key
          super(key)
        else
          super || !exist?
        end
      end

      # Save the provider if any changes have been made
      #
      # @return [self]
      def save
        save_provider if dirty?
        self
      end

      protected

      # Save the provider
      #
      # @return [self]
      def save_provider
        req_args = {
          username: version.box.username,
          name: version.box.name,
          version: version.version,
          provider: name,
          checksum: checksum,
          checksum_type: checksum_type
        }
        if exist?
          result = version.box.organization.account.client.box_version_provider_update(**req_args)
        else
          result = version.box.organization.account.client.box_version_provider_create(**req_args)
        end
        clean(data: result)
        self
      end
    end
  end
end
