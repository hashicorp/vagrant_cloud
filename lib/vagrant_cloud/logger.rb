module VagrantCloud
  module Logger

    @@lock = Mutex.new

    # @return [Log4r::Logger] default logger
    def self.default
      @@lock.synchronize do
        if !@logger
          # Require Log4r and define the levels we'll be using
          require 'log4r/config'
          Log4r.define_levels(*Log4r::Log4rConfig::LogLevels)

          level = nil
          begin
            level = Log4r.const_get(ENV.fetch("VAGRANT_CLOUD_LOG", "FATAL").upcase)
          rescue NameError
            # This means that the logging constant wasn't found,
            # which is fine. We just keep `level` as `nil`. But
            # we tell the user.
            level = nil
          end

          # Some constants, such as "true" resolve to booleans, so the
          # above error checking doesn't catch it. This will check to make
          # sure that the log level is an integer, as Log4r requires.
          level = nil if !level.is_a?(Integer)

          # Only override the log output format if the default is set
          if Log4r::Outputter.stderr.formatter.is_a?(Log4r::DefaultFormatter)
            base_formatter = Log4r::PatternFormatter.new(
              pattern: "%d [%5l] %m",
              date_pattern: "%F %T"
            )
            Log4r::Outputter.stderr.formatter = base_formatter
          end

          logger = Log4r::Logger.new("vagrantcloud")
          logger.outputters = Log4r::Outputter.stderr
          logger.level = level
          @logger = logger
        end
      end
      @logger
    end

    def self.included(klass)
      klass.class_variable_set(:@@logger, Log4r::Logger.new(klass.name.downcase))
      klass.class_eval { define_method(:logger) { self.class.class_variable_get(:@@logger) } }
    end

    # @return [Log4r::Logger] logger instance for current context
    def logger
      @@lock.synchronize do
        if !@logger
          @logger = Log4r::Logger.new(self.class.name.downcase)
        end
        @logger
      end
    end
  end

  Logger.default
end
