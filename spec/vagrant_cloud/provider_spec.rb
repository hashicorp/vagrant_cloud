require 'spec_helper'
require 'vagrant_cloud'

module VagrantCloud
  describe Provider do

    let (:account) { Account.new('my-acc', 'my-token') }
    let (:box) { Box.new(account, 'my-box') }
    let (:version) { VagrantCloud::Version.new(box, '1.2') }

    describe '#initialize' do
      it 'stores data' do
        data = {
          'original_url' => 'http://example.com/foo',
          'download_url' => 'http://vagrant.com/foo',
        }
        provider = Provider.new(version, 'my-prov', data)

        expect(provider.version).to eq(version)
        expect(provider.data).to eq(data)
        expect(provider.url).to eq('http://example.com/foo')
        expect(provider.download_url).to eq('http://vagrant.com/foo')
      end
    end

    describe '.update' do
      it 'sends a PUT request and assigns the result' do
        result = {
          'foo' => 'foo',
        }
        stub_request(:put, 'https://atlas.hashicorp.com/api/v1/box/my-acc/my-box/version/1.2/provider/my-prov').with(
          :body => {
            :access_token => 'my-token',
            :provider => {
              :url => 'http://example.com',
            }
          }
        ).to_return(status: 200, body: JSON.dump(result))

        provider = Provider.new(version, 'my-prov')
        provider.update('http://example.com')

        expect(provider.data).to eq(result)
      end
    end

    describe '.delete' do
      it 'sends a DELETE request' do
        stub_request(:delete, 'https://atlas.hashicorp.com/api/v1/box/my-acc/my-box/version/1.2/provider/my-prov').with(
          :body => {
            :access_token => 'my-token',
          }
        ).to_return(status: 200, body: JSON.dump({}))

        provider = Provider.new(version, 'my-prov')
        provider.delete
      end
    end

  end
end
