module VagrantCloud
  class Organization < Data::Mutable
    attr_reader :account

    attr_required :username
    attr_optional :boxes, :avatar_url, :profile_html, :profile_markdown

    attr_mutable :boxes

    def initialize(account:, **opts)
      @account = account
      opts[:boxes] ||= []
      super(**opts)
      bxs = boxes.map do |b|
        if !b.is_a?(Box)
          b = Box.load(organization: self, **b)
        end
        b
      end
      clean(data: {boxes: bxs})
    end

    # Add a new box to the organization
    #
    # @param [String] name Name of the box
    # @return [Box]
    def add_box(name)
      if boxes.any? { |b| b.name == name }
        raise Error::BoxError::BoxExistsError,
          "Box with name #{name} already exists"
      end
      b = Box.new(organization: self, name: name)
      clean(data: {boxes: boxes + [b]})
      b
    end

    # Check if this instance is dirty
    #
    # @param [Boolean] deep Check nested instances
    # @return [Boolean] instance is dirty
    def dirty?(key=nil, deep: false)
      if key
        super(key)
      else
        d = super()
        if deep && !d
          d = boxes.any? { |b| b.dirty?(deep: true) }
        end
        d
      end
    end

    # Save the organization
    #
    # @return [self]
    # @note This only saves boxes within organization
    def save
      boxes.map(&:save)
      self
    end
  end
end
