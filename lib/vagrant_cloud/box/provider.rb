module VagrantCloud
  class Box
    class Provider < Data::Mutable

      # Result for upload requests to upload directly to the
      # storage backend.
      #
      # @param [String] upload_url URL for uploading file asset
      # @param [String] callback_url URL callback to PUT after successful upload
      # @param [Proc] callback Callable proc to perform callback via configured client
      DirectUpload = Struct.new(:upload_url, :callback_url, :callback, keyword_init: true)

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
          pv = version.providers.dup
          pv.delete(self)
          version.clean(data: {providers: pv})
        end
        nil
      end

      # Upload box file to be hosted on VagrantCloud. This
      # method provides different behaviors based on the
      # parameters passed. When the `direct` option is enabled
      # the upload target will be directly to the backend
      # storage. However, when the `direct` option is used the
      # upload process becomes a two steps where a callback
      # must be called after the upload is complete.
      #
      # If the path is provided, the file will be uploaded
      # and the callback will be requested if the `direct`
      # option is enabled.
      #
      # If a block is provided, the upload URL will be yielded
      # to the block. If the `direct` option is set, the callback
      # will be automatically requested after the block execution
      # has completed.
      #
      # If no path or block is provided, the upload URL will
      # be returned. If the `direct` option is set, the
      # `DirectUpload` instance will be yielded and it is
      # the caller's responsibility to issue the callback
      #
      # @param [String] path Path to asset
      # @param [Boolean] direct Upload directly to backend storage
      # @yieldparam [String] url URL to upload asset
      # @return [self, Object, String, DirectUpload] self when path provided, result of yield when block provided, URL otherwise
      # @note The callback request uses PUT request method
      def upload(path: nil, direct: false)
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
        req_args = {
          username: version.box.username,
          name: version.box.name,
          version: version.version,
          provider: name
        }
        if direct
          r = version.box.organization.account.client.box_version_provider_upload_direct(**req_args)
        else
          r = version.box.organization.account.client.box_version_provider_upload(**req_args)
        end
        result = DirectUpload.new(
          upload_url: r[:upload_path],
          callback_url: r[:callback],
          callback: proc {
            if r[:callback]
              version.box.organization.account.client.
                request(method: :put, path: URI.parse(r[:callback]).path)
            end
          }
        )
        if block_given?
          block_r = yield result.upload_url
          result[:callback].call
          block_r
        elsif path
          File.open(path, "rb") do |file|
            chunks = lambda { file.read(Excon.defaults[:chunk_size]).to_s }
            Excon.put(result.upload_url, request_block: chunks)
          end
          result[:callback].call
          self
        else
          # When returning upload information for requester to complete,
          # return upload URL when `direct` option is false, otherwise
          # return the `DirectUpload` instance
          direct ? result : result.upload_url
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
