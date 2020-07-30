module VagrantCloud
  module Instrumentor
    class Collection < Core
      # @return [Set<Instrumentor::Core>]
      attr_reader :instrumentors
      # @return [Set<Callable>]
      attr_reader :subscriptions

      # Create a new instance
      #
      # @param [Array<Core>] instrumentors Instrumentors to add to collection
      def initialize(instrumentors: [])
        @lock = Mutex.new
        @subscriptions = Set.new
        @instrumentors = Set.new
        # Add our default
        @instrumentors << Logger.new

        Array(instrumentors).each do |i|
          if !i.is_a?(Core) && !i.respond_to?(:instrument)
            raise TypeError, "Instrumentors must implement `#instrument`"
          end
          @instrumentors << i
        end
        @instrumentors.freeze
      end

      # Add a new instrumentor
      #
      # @param [Core] instrumentor New instrumentor to add
      # @return [self]
      def add(instrumentor)
        @lock.synchronize do
          if !instrumentor.is_a?(Core) && !instrumentor.respond_to?(:instrument)
            raise TypeError, "Instrumentors must implement `#instrument`"
          end

          @instrumentors = (instrumentors + [instrumentor]).freeze
        end
        self
      end

      # Remove instrumentor
      #
      # @param [Core] instrumentor Remove instrumentor from collection
      # @return [self]
      def remove(instrumentor)
        @lock.synchronize do
          @instrumentors = instrumentors.dup.tap{|i| i.delete(instrumentor)}.freeze
        end
        self
      end

      # Add a subscription for events
      #
      # @param [Regexp, String] event Event to match
      def subscribe(event, callable=nil, &block)
        if callable && block
          raise ArgumentError, "Callable argument or block expected, not both"
        end
        c = callable || block
        if !c.respond_to?(:call)
          raise TypeError, "Callable action is required for subscription"
        end
        entry = [event, c]
        @lock.synchronize do
          @subscriptions = (@subscriptions + [entry]).freeze
        end
        self
      end

      def unsubscribe(callable)
        @lock.synchronize do
          subscriptions = @subscriptions.dup
          subscriptions.delete_if { |entry| entry.last == callable }
          @subscriptions = subscriptions.freeze
        end
        self
      end

      # Call all instrumentors in collection with given parameters
      def instrument(name, params = {})
        # Log the start time
        timing = {start_time: Time.now}

        # Run the action
        result = yield if block_given?

        # Log the completion time and calculate duration
        timing[:complete_time] = Time.now
        timing[:duration] = timing[:complete_time] - timing[:start_time]

        # Insert timing into params
        params[:timing] = timing

        # Call any instrumentors we know about
        @lock.synchronize do
          # Call our instrumentors first
          instrumentors.each do |i|
            i.instrument(name, params)
          end
          # Now call any matching subscriptions
          subscriptions.each do |event, callable|
            if event.is_a?(Regexp)
              next if !event.match(name)
            else
              next if event != name
            end
            args = [name, params]

            if callable.arity > -1
              args = args[0, callable.arity]
            end

            callable.call(*args)
          end
        end

        result
      end
    end
  end
end
