module VagrantCloud
  module Instrumentor
    class Logger < Core
      REDACTED = "REDACTED".freeze

      include VagrantCloud::Logger

      # Perform event logging
      #
      # @param [String] name Name of event "namespace.event"
      # @param [Hash] params Data available with event
      def instrument(name, params = {})
        namespace, event = name.split(".", 2)

        if event == "error"
          logger.error { "#{namespace} #{event.upcase} #{params[:error]}" }
          return
        end

        logger.info do
          case namespace
          when "excon"
            # Make a copy so we can modify
            params = params.dup
            info = excon(event, params)
          else
            info = params.dup
          end
          "#{namespace} #{event.upcase} #{format_output(info)}"
        end

        logger.debug do
          "#{namespace} #{event.upcase} #{format_output(params)}"
        end
      end

      # Format output to make it look nicer
      #
      # @param [Hash] info Output information
      # @return [String]
      def format_output(info)
        info.map do |key, value|
          if value.is_a?(Enumerable)
            value = value.map{ |k,v| [k, v].compact.join(": ") }.join(", ")
          end
          "#{key}=#{value.inspect}"
        end.join(" ")
      end

      # Generate information based on excon event
      #
      # @param [String] event Event name
      # @param [Hash] params Event data
      # @return [Hash] data to be printed
      def excon(event, params)
        # Remove noisy stuff that may be present from excon
        params.delete(:connection)
        params.delete(:stack)

        # Remove any credential information
        params[:password] = REDACTED if params.key?(:password)
        params[:access_token] = REDACTED if params[:access_token]
        if params.dig(:headers, "Authorization") || params.dig(:headers, "Proxy-Authorization")
          params[:headers] = params[:headers].dup.tap do |h|
            h["Authorization"] = REDACTED if h["Authorization"]
            h["Proxy-Authorization"] = REDACTED if h["Proxy-Authorization"]
          end
        end
        if params.dig(:proxy, :password)
          params[:proxy] = params[:proxy].dup.tap do |proxy|
            proxy[:password] = REDACTED
          end
        end

        info = {}

        case event
        when "request", "retry"
          info[:method] = params[:method]
          info[:identifier] = params.dig(:headers, 'X-Request-Id')
          info[:url] = "#{params[:scheme]}://#{File.join(params[:host], params[:path])}"
          info[:query] = params[:query] if params[:query]
          info[:headers] = params[:headers] if params[:headers]
        when "response"
          info[:status] = params[:status]
          info[:identifier] = params.dig(:headers, 'X-Request-Id')
          info[:body] = params[:body]
        else
          info = params.dup
        end
        duration = (params.dig(:timing, :duration).to_f * 1000).to_i
        info[:duration] = "#{duration}ms"
        info
      end
    end
  end
end
