require 'spec_helper'
require 'vagrant_cloud'

module VagrantCloud
  describe Search do
    let(:token) { 'my-token' }
    let(:account) { Account.new('my-acc', token) }
    let(:client) { Account.new(token) }

    describe '.search' do
      it 'sends a GET request' do
        result = {
          'foo' => 'foo'
        }
        stub_request(:get, 'https://vagrantcloud.com/api/v1/search?limit=10&order=desc&page=1&provider=virtualbox&q=ubuntu&sort=downloads').
          to_return(status: 200, body: JSON.dump(result))

        search = Search.new(token)
        search.search('ubuntu', 'virtualbox', 'downloads', 'desc', 10, 1)
      end
    end
  end
end
