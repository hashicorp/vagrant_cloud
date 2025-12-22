# Copyright IBM Corp. 2014, 2025
# SPDX-License-Identifier: MIT

require 'webmock/rspec'

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

WebMock.disable_net_connect!(allow_localhost: true)

ENV.delete("VAGRANT_CLOUD_TOKEN")
