module VagrantCloud
  class Response
    class Search < Response
      # @return [Account]
      attr_reader :account
      # @return [Hash] search parameters
      attr_reader :search_parameters

      attr_optional :boxes

      def initialize(account:, params:, **opts)
        if !account.is_a?(Account)
          raise TypeError,
            "Expected type `#{Account.name}` but received `#{account.class.name}`"
        end
        @account = account
        @search_parameters = params
        opts[:boxes] = reload_boxes(opts[:boxes])
        super(**opts)
      end

      # @return [Integer]
      def page
        pg = @search_parameters.fetch(:page, 0).to_i
        pg > 0 ? pg : 1
      end

      # @return [Search] previous page of search results
      def previous
        if page <= 1
          raise ArgumentError,
            "Cannot request page results less than one"
        end
        account.searcher.from_response(self) do |s|
          s.prev_page
        end
      end

      # @return [Search] next page of search results
      def next
        account.searcher.from_response(self) do |s|
          s.next_page
        end
      end

      protected

      # Load all the box data into proper instances
      def reload_boxes(boxes)
        org_cache = {}
        boxes.map do |b|
          org_name = b[:username]
          if !org_cache[org_name]
            org_cache[org_name] = account.organization(name: org_name)
          end
          org = org_cache[org_name]
          box = Box.new(organization: org, **b)
          org.boxes = org.boxes + [box]
          org.clean!
          box
        end
      end
    end
  end
end
