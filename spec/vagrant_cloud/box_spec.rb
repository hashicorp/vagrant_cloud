require 'spec_helper'
require 'vagrant_cloud'

module VagrantCloud
  describe Box do
    let (:account) { Account.new('my-acc', 'my-token') }

    describe '#initialize' do
      it 'stores data' do
        data = {
          'description_markdown' => 'desc-markdown',
          'short_description' => 'desc-short',
          'private' => false,
          'versions' => []
        }
        box = Box.new(account, 'foo', data)

        expect(box.account).to eq(account)
        expect(box.data).to eq(data)
        expect(box.name).to eq('foo')
        expect(box.description).to eq('desc-markdown')
        expect(box.description_short).to eq('desc-short')
        expect(box.private).to eq(false)
      end
    end

    describe '.versions' do
      it 'returns version in the right order' do
        box = Box.new(account, 'foo', 'versions' => [
                        { 'number' => '2.0' },
                        { 'number' => '1.0' }
                      ])

        expect(box.versions.length).to eq(2)
        expect(box.versions[0].number).to eq('1.0')
        expect(box.versions[1].number).to eq('2.0')
      end
    end

    describe '.update' do
      it 'sends a PUT request and assigns the result' do
        result = {
          'foo' => 'foo'
        }
        stub_request(:put, 'https://vagrantcloud.com/api/v1/box/my-acc/foo').with(
          body: {
            access_token: 'my-token',
            box: {
              short_description: 'my-desc',
              description: 'my-desc',
              is_private: 'true'
            }
          }
        ).to_return(status: 200, body: JSON.dump(result))

        box = Box.new(account, 'foo')
        box.update(description: 'my-desc',
                   short_description: 'my-desc',
                   is_private: true)

        expect(box.data).to eq(result)
      end
    end

    describe '.delete' do
      it 'sends a DELETE request' do
        stub_request(:delete, 'https://vagrantcloud.com/api/v1/box/my-acc/foo').with(
          body: {
            access_token: 'my-token'
          }
        ).to_return(status: 200, body: JSON.dump({}))

        box = Box.new(account, 'foo')
        box.delete
      end
    end

    describe '.create_version' do
      it 'sends a POST request and returns the right instance' do
        result = {
          'number' => '1.2',
          'foo' => 'foo'
        }
        stub_request(:post, 'https://vagrantcloud.com/api/v1/box/my-acc/foo/versions').with(
          body: {
            access_token: 'my-token',
            version: {
              version: '1.2',
              description: 'my-desc'
            }
          }
        ).to_return(status: 200, body: JSON.dump(result))

        box = Box.new(account, 'foo')
        version = box.create_version('1.2', 'my-desc')

        expect(version).to be_a(Version)
        expect(version.data).to eq(result)
      end
    end

    describe '.ensure_version' do
      it 'creates nonexisting versions' do
        box = Box.new(account, 'foo')
        version_created = VagrantCloud::Version.new(box, '1.2', 'description_markdown' => 'my-desc')
        expect(box).to receive(:versions).and_return([])
        expect(box).to receive(:create_version).with('1.2', 'my-desc').and_return(version_created)

        version = box.ensure_version('1.2', 'my-desc')
        expect(version).to eq(version_created)
      end

      it 'returns existing versions' do
        box = Box.new(account, 'foo')
        version_requested = VagrantCloud::Version.new(box, '1.2', 'version' => '1.2',
                                                                  'description_markdown' => 'my-desc')
        expect(box).to receive(:versions).and_return([version_requested])

        version = box.ensure_version('1.2', 'my-desc')
        expect(version).to eq(version_requested)
      end

      it 'updates existing versions' do
        box = Box.new(account, 'foo')
        version_requested = VagrantCloud::Version.new(box, '1.2', 'version' => '1.2',
                                                                  'description_markdown' => 'my-desc')
        expect(box).to receive(:versions).and_return([version_requested])
        expect(version_requested).to receive(:update).with('my-desc2')

        version = box.ensure_version('1.2', 'my-desc2')
        expect(version).to eq(version_requested)
      end
    end
  end
end
