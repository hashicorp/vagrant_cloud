require 'spec_helper'
require 'vagrant_cloud'

module VagrantCloud
  describe Client do
    let (:token) { "my-token" }
    let (:client) { Client.new(token) }

    describe '#request' do
      it "includes an Authorization header" do
        stub_request(:get, 'https://vagrantcloud.com/api/v1/foo')
          .with(headers: { "Authorization" => "Bearer my-token" })
          .to_return(status: 200, body: JSON.dump(bar: 'bar'))

        expect(client.request(:get, '/foo')).to eq('bar' => 'bar')
      end

      it 'parses GET response' do
        stub_request(:get, 'https://vagrantcloud.com/api/v1/foo')
          .to_return(status: 200, body: JSON.dump(bar: 'bar'))

        expect(client.request(:get, '/foo')).to eq('bar' => 'bar')
      end

      it 'sends POST params and parses response' do
        stub_request(:post, 'https://vagrantcloud.com/api/v1/foo').with(
          body: {
            foo: 'foo'
          }
        ).to_return(status: 200, body: JSON.dump(bar: 'bar'))

        expect(client.request(:post, '/foo', foo: 'foo')).to eq('bar' => 'bar')
      end

      it 'raises on errors' do
        stub_request(:get, 'https://vagrantcloud.com/api/v1/foo')
          .to_return(status: 500, body: JSON.dump(errors: ['bar', 'foo']))

        expect { client.request(:get, '/foo', foo: 'foo') }
          .to raise_error(VagrantCloud::ClientError, "500 Internal Server Error - bar, foo")
      end

      it 'raises on errors with an error array' do
        stub_request(:get, 'https://vagrantcloud.com/api/v1/foo')
          .to_return(status: 500, body: JSON.dump(errors: 'bar'))

        expect { client.request(:get, '/foo', foo: 'foo') }
          .to raise_error(VagrantCloud::ClientError, "500 Internal Server Error - bar")
      end
    end
  end
end
