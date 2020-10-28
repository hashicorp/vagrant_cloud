module VagrantCloud
  class Error < StandardError
    class ClientError < Error
      class RequestError < ClientError
        attr_accessor :error_code
        attr_accessor :error_arr

        def initialize(msg, http_body, http_code)
          message = msg

          begin
            errors = JSON.parse(http_body)
            if errors.is_a?(Hash)
              vagrant_cloud_msg = errors['errors']
              if vagrant_cloud_msg.is_a?(Array)
                message = msg + ' - ' + vagrant_cloud_msg.map(&:to_s).join(', ').to_s
              elsif !vagrant_cloud_msg.to_s.empty?
                message = msg + ' - ' + vagrant_cloud_msg.to_s
              end
            end
          rescue JSON::ParserError => err
            vagrant_cloud_msg = err.message
          end

          @error_arr = Array(vagrant_cloud_msg)
          @error_code = http_code.to_i
          super(message)
        end
      end

      class ConnectionLockedError < ClientError; end
    end

    class BoxError < Error
      class InvalidVersionError < BoxError
        def initialize(version_number)
          message = 'Invalid version given: ' + version_number
          super(message)
        end
      end
      class BoxExistsError < BoxError; end
      class ProviderNotFoundError < BoxError; end
      class VersionExistsError < BoxError; end
      class VersionStatusChangeError < BoxError; end
      class VersionProviderExistsError < BoxError; end
    end
  end
end
