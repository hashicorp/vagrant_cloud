require 'spec_helper'
require 'vagrant_cloud'

describe VagrantCloud::Account do

  let (:account) { VagrantCloud::Account.new('my-username', 'my-token') }

  describe '#initialize' do
    it 'stores credentials' do
      expect(account.username).to eq('my-username')
      expect(account.access_token).to eq('my-token')
    end
  end

  describe '.request' do
    it 'sends post params' do
      stub_request(:post, 'https://vagrantcloud.com/api/v1/foo').with(
        :body => {
          :access_token => 'my-token',
          :foo => 'foo',
        },
        :headers => {
          :access_token => 'my-token',
        }
      ).to_return(status: 200, body: JSON.dump({:bar => 'bar'}))

      expect(account.request(:post, '/foo', {:foo => 'foo'})).to eq({'bar' => 'bar'})
    end

    it 'sends get params' do
      stub_request(:get, 'https://vagrantcloud.com/api/v1/foo').with(
        :body => {
          :access_token => 'my-token',
          :foo => 'foo',
        },
        :headers => {
          :access_token => 'my-token',
        }
      ).to_return(status: 200, body: JSON.dump({:bar => 'bar'}))

      expect(account.request(:get, '/foo', {:foo => 'foo'})).to eq({'bar' => 'bar'})
    end

    it 'raises on error' do
      stub_request(:get, 'https://vagrantcloud.com/api/v1/foo').
        to_return(status: 200, body: JSON.dump({:errors => 'bar'}))

      expect { account.request(:get, '/foo', {:foo => 'foo'}) }.
        to raise_error(RuntimeError, 'Vagrant Cloud returned error: bar')
    end
  end

  describe '.create_box' do
    it 'creates and returns box' do
      result = {'return_foo' => 'foo'}
      stub_request(:post, 'https://vagrantcloud.com/api/v1/boxes').with(:body =>
          {
            :access_token => 'my-token',
            :box => {
              :name => 'my-name',
              :description => 'my-desc',
              :short_description => 'my-desc',
              :is_private => '1',
            }
          }).to_return(status: 200, body: JSON.dump(result))

      box = account.create_box('my-name', 'my-desc', true)
      expect(box).to be_a(VagrantCloud::Box)
      expect(box.data).to eq(result)
    end
  end

end
