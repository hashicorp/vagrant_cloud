module VagrantCloud
  class Search
    # @return [Account]
    attr_reader :account

    # Create a new search instance
    #
    # @param [String] access_token Authentication token
    # @param [Account] account Account instance
    # @param [Client] client Client instance
    # @return [Search]
    def initialize(access_token: nil, account: nil, client: nil)
      args = {access_token: access_token, account: account, client: client}.compact
      if args.size > 1
        raise ArgumentError,
          "Search accepts `access_token`, `account`, or `client` but received multiple (#{args.keys.join(", ")})"
      end
      if client
        if !client.is_a?(Client)
          raise TypeError,
            "Expecting type `#{Client.name}` but received `#{client.class.name}`"
        end
        @account = Account.new(client: client)
      elsif account
        if !account.is_a?(Account)
          raise TypeError,
            "Expecting type `#{Account.name}` but received `#{account.class.name}`"
        end
        @account = account
      else
        @account = Account.new(access_token: access_token)
      end
      @params = {}
      @lock = Mutex.new
    end

    # Requests a search based on the given parameters
    #
    # @param [String] query
    # @param [String] provider
    # @param [String] sort
    # @param [String] order
    # @param [String] limit
    # @param [String] page
    # @return [Response::Search]
    def search(query: Data::Nil, provider: Data::Nil, sort: Data::Nil, order: Data::Nil, limit: Data::Nil, page: Data::Nil)
      @lock.synchronize do
        @params = {
          query: query,
          provider: provider,
          sort: sort,
          order: order,
          limit: limit,
          page: page
        }
        execute
      end
    end

    # Request the next page of the search results
    #
    # @param [Response::Search]
    def next_page
      @lock.synchronize do
        if @params.empty?
          raise ArgumentError, "No active search currently cached"
        end
        page = @params[:page].to_i
        page = 1 if page < 1
        @params[:page] = page + 1
        execute
      end
    end

    # Request the previous page of the search results
    #
    # @param [Response::Search]
    def prev_page
      @lock.synchronize do
        if @params.empty?
          raise ArgumentError, "No active search currently cached"
        end
        page = @params[:page].to_i - 1
        @params[:page] = page < 1 ? 1 : page
        execute
      end
    end

    # @return [Boolean] Search terms are stored
    def active?
      !@params.empty?
    end

    # Clear the currently cached search parameters
    #
    # @return [self]
    def clear!
      @lock.synchronize { @params.clear }
      self
    end

    # Seed the parameters
    #
    # @return [self]
    def seed(**params)
      @lock.synchronize { @params = params }
      self
    end

    # Generate a new instance seeded with search
    # parameters from given response
    #
    # @param [Response::Search] response Search response
    # @yieldparam [Search] Seeded search instance
    # @return [Object] result of given block
    def from_response(response)
      s = self.class.new(account: account)
      yield s.seed(**response.search_parameters)
    end

    protected

    # @return [Response::Search]
    def execute
      r = account.client.search(**@params)
      Response::Search.new(account: account, params: @params, **r)
    end
  end
end
