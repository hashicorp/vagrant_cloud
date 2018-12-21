module VagrantCloud
  class ClientError < StandardError
    attr_accessor :error_arr
    attr_accessor :error_code

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

      @error_arr = vagrant_cloud_msg
      @error_code = http_code.to_i
      super(message)
    end
  end

  class InvalidVersion < StandardError
    def initialize(version_number)
      message = 'Invalid version given: ' + version_number
      super(message)
    end
  end
end
