module VagrantCloud
  module Instrumentor
    class Core
      def instrument(*_)
        raise NotImplementedError
      end
    end
  end
end
