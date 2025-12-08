# Copyright IBM Corp. 2014, 2025
# SPDX-License-Identifier: MIT

module VagrantCloud
  class Response
    class Request2FA < Response
      attr_required :destination
    end
  end
end
