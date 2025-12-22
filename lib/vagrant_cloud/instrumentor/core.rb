# Copyright IBM Corp. 2014, 2025
# SPDX-License-Identifier: MIT

module VagrantCloud
  module Instrumentor
    class Core
      def instrument(*_)
        raise NotImplementedError
      end
    end
  end
end
