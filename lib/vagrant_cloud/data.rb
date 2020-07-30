module VagrantCloud
  # Generic data class which provides simple attribute
  # data storage using a Hash like interface
  class Data
    # Custom nil class which is used for signifying
    # a nil value that was not set by the user. This
    # makes it easy to filter out values which are
    # unset vs. those that are set to nil.
    class NilClass < BasicObject
      include ::Singleton
      def nil?; true; end
      def ==(v); v.nil? || super(v); end
      def ===(v); equal?(v); end
      def equal?(v); v.nil? || super(v); end
      def to_i; 0; end
      def to_f; 0.0; end
      def to_a; []; end
      def to_h; {}; end
      def to_s; ""; end
      def &(_); false; end
      def |(_); false; end
      def ^(_); false; end
      def !; true; end
      def inspect; 'nil'; end
    end

    # Easy to use constant to access general
    # use instance of our custom nil class
    Nil = NilClass.instance

    # Create a new instance
    #
    # @return [Data]
    def initialize(**opts)
      @data = opts
    end

    # Fetch value from data
    #
    # @param [String, Symbol] k Name of value
    # @return [Object]
    def [](k)
      @data.key?(k.to_sym) ? @data[k.to_sym] : Nil
    end

    # @return [String]
    def inspect
      "<#{self.class.name}:#{sprintf("%#x", object_id)}>"
    end

    protected def data; @data; end

    # Immutable data class. This class adds extra functionality to the Data
    # class like providing attribute methods which can be defined using the
    # `attr_required` and `attr_optional` methods. Once an instance is created
    # the data is immutable. For example:
    #
    # class MyData < Immutable
    #   attr_required :name
    #   attr_optional :version
    # end
    #
    # When creating a new instance, a name parameter _must_ be provided,
    # but a version parameter is optional, so both are valid:
    #
    # instance = MyData.new(name: "testing", version: "new-version")
    #
    # and
    #
    # instance = MyData.new(name: "testing")
    #
    # but only providing the version is invalid:
    #
    # instance = MyData.new(version: "new-version") # -> Exception
    class Immutable < Data
      @@lock = Mutex.new

      # Define attributes which are required
      def self.attr_required(*args)
        return @required || [] if args.empty?
        sync do
          @required ||= []
          if !args.empty?
            # Create any accessor methods which do not yet exist
            args = args.map(&:to_sym) - @required
            args.each do |argument_name|
              if !method_defined?(argument_name)
                define_method(argument_name) {
                  send(:[], argument_name.to_sym)
                }
              end
            end
            @required += args
          end
          @required
        end
      end

      # Define attributes which are optional
      def self.attr_optional(*args)
        return @optional || [] if args.empty?
        sync do
          @optional ||= []
          if !args.empty?
            # Create any accessor method which do not yet exist
            args = args.map(&:to_sym) - @optional
            args.each do |argument_name|
              if !method_defined?(argument_name)
                define_method(argument_name) {
                  send(:[], argument_name.to_sym)
                }
              end
            end
            @optional += args
          end
          @optional
        end
      end

      # If inherited, set attribute information
      def self.inherited(klass)
        klass.attr_required(*attr_required)
        klass.attr_optional(*attr_optional)
        klass.class_variable_set(:@@lock, Mutex.new)
      end

      # Synchronize action
      def self.sync
        @@lock.synchronize do
          yield
        end
      end

      # Create a new instance
      #
      # @return [Immutable]
      def initialize(**opts)
        super()
        self.class.attr_required.each do |attr|
          if !opts.key?(attr)
            raise ArgumentError, "Missing required parameter `#{attr}`"
          end
          data[attr.to_sym] = opts[attr].dup
        end
        self.class.attr_optional.each do |attr|
          if opts.key?(attr)
            data[attr.to_sym] = opts[attr].dup
          end
        end
        extras = opts.keys - (self.class.attr_required + self.class.attr_optional)
        if !extras.empty?
          raise ArgumentError, "Unknown parameters provided: #{extras.join(",")}"
        end
        freezer(@data)
      end

      # @return [String]
      def inspect
        vars = (self.class.attr_required + self.class.attr_optional).map do |k|
          val = self.send(:[], k)
          next if val.nil? || val.to_s.empty?
          "#{k}=#{val.inspect}"
        end.compact.join(", ")
        "<#{self.class.name}:#{sprintf("%#x", object_id)} #{vars}>"
      end

      protected

      # Freeze the given object and all nested
      # objects that can be found
      #
      # @return [Object]
      def freezer(obj)
        if obj.is_a?(Enumerable)
          obj.each do |item|
            freezer(item)
            item.freeze
          end
        end
        obj.freeze
      end
    end

    # Mutable data class
    class Mutable < Immutable
      # Define attributes which are mutable
      def self.attr_mutable(*args)
        sync do
          args.each do |attr|
            if !attr_required.include?(attr.to_sym) && !attr_optional.include?(attr.to_sym)
              raise ArgumentError, "Unknown attribute name provided `#{attr}`"
            end
            define_method("#{attr}=") { |v| dirty[attr.to_sym] = v }
          end
        end
      end

      # Load data and create a new instance
      #
      # @param [Hash] options Value to initialize instance
      # @return [Mutable]
      def self.load(options={})
        opts = {}.tap do |o|
          (attr_required + attr_optional +
            self.instance_method(:initialize).parameters.find_all { |i|
            i.first == :key || i.first == :keyreq
          }.map(&:last)).each do |k|
            o[k.to_sym] = options[k.to_sym]
          end
        end
        self.new(**opts)
      end

      # Create a new instance
      #
      # @return [Mutable]
      def initialize(**opts)
        super
        @dirty = {}
      end

      # Fetch value from data
      #
      # @param [String, Symbol] k Name of value
      # @return [Object]
      def [](k)
        if dirty?(k)
          @dirty[k.to_sym]
        else
          super
        end
      end

      # Check if instance is dirty or specific
      # attribute if key is provided
      #
      # @param [Symbol] key Key to check
      # @return [Boolean] instance is dirty
      def dirty?(key=nil, **opts)
        if key.nil?
          !@dirty.empty?
        else
          @dirty.key?(key.to_sym)
        end
      end

      # Load given data and ignore any fields
      # that are provided. Flush dirty state.
      #
      # @param [Hash] data Attribute data to load
      # @param [Array<Symbol>] ignores Fields to skip
      # @param [Array<Symbol>] only Fields to update
      # @return [self]
      def clean(data:, ignores: [], only: [])
        raise TypeError, "Expected type `Hash` but received `#{data.inspect}`" if
          !data.is_a?(Hash)
        new_data = @data.dup
        ignores = Array(ignores).map(&:to_sym)
        only = Array(only).map(&:to_sym)
        data.each do |k, v|
          k = k.to_sym
          next if ignores.include?(k)
          next if !only.empty? && !only.include?(k)
          if self.respond_to?(k)
            new_data[k] = v
            @dirty.delete(k)
          end
        end
        @data = freezer(new_data)
        self
      end

      # Merge values from dirty cache into data
      #
      # @return [self]
      def clean!
        @data = freezer(@data.merge(@dirty))
        @dirty.clear
        self
      end

      # @return [self] disable freezing
      def freeze
        self
      end

      # @return [Hash] updated attributes
      protected def dirty; @dirty; end
    end
  end

  Nil = Data::Nil
end
