require 'spec_helper'
require 'vagrant_cloud'

module VagrantCloud
  describe Account do
    let (:account) { Account.new('my-acc', 'my-token') }

    describe '#initialize' do
      it 'stores credentials' do
        expect(account.username).to eq('my-acc')
        expect(account.access_token).to eq('my-token')
      end
    end

    describe '.request' do
      it 'parses GET response' do
        stub_request(:get, 'https://vagrantcloud.com/api/v1/foo')
          .to_return(status: 200, body: JSON.dump(bar: 'bar'))

        expect(account.request(:get, '/foo')).to eq('bar' => 'bar')
      end

      it 'sends POST params and parses response' do
        stub_request(:post, 'https://vagrantcloud.com/api/v1/foo').with(
          body: {
            access_token: 'my-token',
            foo: 'foo'
          }
        ).to_return(status: 200, body: JSON.dump(bar: 'bar'))

        expect(account.request(:post, '/foo', foo: 'foo')).to eq('bar' => 'bar')
      end

      it 'raises on errors' do
        stub_request(:get, 'https://vagrantcloud.com/api/v1/foo')
          .to_return(status: 200, body: JSON.dump(errors: 'bar'))

        expect { account.request(:get, '/foo', foo: 'foo') }
          .to raise_error(RuntimeError, 'Vagrant Cloud returned error: bar')
      end
    end

    describe '.create_box' do
      it 'creates and returns box' do
        result = { 'return_foo' => 'foo' }
        stub_request(:post, 'https://vagrantcloud.com/api/v1/boxes').with(
          body: {
            access_token: 'my-token',
            box: {
              name: 'my-name',
              description: 'my-desc',
              short_description: 'my-desc',
              is_private: 'true'
            }
          }
        ).to_return(status: 200, body: JSON.dump(result))

        box = account.create_box('my-name',
                                 description: 'my-desc',
                                 short_description: 'my-desc',
                                 is_private: true)
        expect(box).to be_a(Box)
        expect(box.data).to eq(result)
      end

      context 'when not passing :is_private' do
        it 'creates a public box' do
          result = { 'return_foo' => 'foo' }
          stub_request(:post, 'https://vagrantcloud.com/api/v1/boxes').with(
            body: {
              access_token: 'my-token',
              box: {
                name: 'my-name',
                description: 'my-desc',
                is_private: 'false'
              }
            }
          ).to_return(status: 200, body: JSON.dump(result))

          box = account.create_box('my-name', description: 'my-desc')
          expect(box).to be_a(Box)
          expect(box.data).to eq(result)
        end
      end
    end

    describe '.ensure_box' do
      it 'creates nonexisting boxes' do
        box_requested = Box.new(account, 'foo')
        expect(box_requested).to receive(:data).and_raise(RestClient::ResourceNotFound)

        box_created = Box.new(account, 'foo', 'description_markdown' => 'desc',
                                              'short_description' => 'desc',
                                              'private' => true)
        expect(account).to receive(:get_box).with('foo').and_return(box_requested)
        expect(account).to receive(:create_box).with('foo', description: 'desc',
                                                            short_description: 'desc',
                                                            is_private: true).and_return(box_created)

        box = account.ensure_box('foo',
                                 description: 'desc',
                                 short_description: 'desc',
                                 is_private: true)
        expect(box).to eq(box_created)
      end

      it 'returns existing boxes' do
        box_requested = Box.new(account, 'foo', 'description_markdown' => 'desc',
                                                'short_description' => 'desc',
                                                'private' => true)
        expect(account).to receive(:get_box).with('foo').and_return(box_requested)

        box = account.ensure_box('foo',
                                 description: 'desc',
                                 short_description: 'desc',
                                 is_private: true)
        expect(box).to eq(box_requested)
      end

      it 'updates existing boxes' do
        box_requested = Box.new(account, 'foo', 'description_markdown' => 'desc2',
                                                'short_description' => 'desc2',
                                                'private' => true)
        expect(account).to receive(:get_box).with('foo').and_return(box_requested)
        expect(box_requested).to receive(:update).with(description: 'desc',
                                                       short_description: 'desc')

        box = account.ensure_box('foo',
                                 description: 'desc',
                                 short_description: 'desc',
                                 is_private: true)
        expect(box).to eq(box_requested)
      end
    end
  end
end
