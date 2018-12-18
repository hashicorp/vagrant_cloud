require 'spec_helper'
require 'vagrant_cloud'

module VagrantCloud
  describe Box do
    let(:account) { Account.new('my-acc', 'my-token') }
    let(:box) { Box.new(account, 'my-box') }

    describe '#initialize' do
      it 'stores data' do
        data = { 'version' => '1.2', 'description_markdown' => 'desc-markdown', 'status' => 'unreleased' }
        version = VagrantCloud::Version.new(box, '1.2', data)

        expect(version.box).to eq(box)
        expect(version.data).to eq(data)
        expect(version.version).to eq('1.2')
        expect(version.description).to eq('desc-markdown')
        expect(version.status).to eq('unreleased')
      end
    end

    describe '.update' do
      it 'sends a PUT request and assigns the result' do
        result = {
          'foo' => 'foo'
        }
        stub_request(:put, 'https://vagrantcloud.com/api/v1/box/my-acc/my-box/version/1.2').with(
          body: {
            version: { description: 'my-desc' }
          }
        ).to_return(status: 200, body: JSON.dump(result))

        version = VagrantCloud::Version.new(box, '1.2')
        version.update('my-desc')

        expect(version.data).to eq(result)
      end

      it 'sents a PUT request and assigns the result for a one off version' do
        result = {
          'foo' => 'foo'
        }
        stub_request(:put, 'https://vagrantcloud.com/api/v1/box/hashicorp/precise64/version/1.2.3').with(
          body: {
            version: { description: 'my-desc' }
          }
        ).to_return(status: 200, body: JSON.dump(result))

        version = VagrantCloud::Version.new(box, '1.2')
        expect(version.update('my-desc', 'hashicorp', 'precise64', '1.2.3'))
          .to eq(result)
      end

      it 'raises an exception if the version number is invalid' do
        version = VagrantCloud::Version.new(box, '1.2.3')
        expect { version.update('my-desc', 'hashicorp', 'precise64', 'v1.2.4') }
          .to raise_error(VagrantCloud::InvalidVersion, 'Invalid version given: v1.2.4')
      end
    end

    describe '.delete' do
      it 'sends a DELETE request' do
        stub_request(:delete, 'https://vagrantcloud.com/api/v1/box/my-acc/my-box/version/1.2')
          .to_return(status: 200, body: JSON.dump({}))

        version = VagrantCloud::Version.new(box, '1.2')
        version.delete
      end

      it 'sends a DELETE request for one-off versions' do
        stub_request(:delete, 'https://vagrantcloud.com/api/v1/box/hashicorp/precise64/version/1.2.3')
          .to_return(status: 200, body: JSON.dump({}))

        version = VagrantCloud::Version.new(box, '1.2')
        version.delete('hashicorp', 'precise64', '1.2.3')
      end
    end

    describe '.release' do
      it 'sends a PUT request' do
        stub_request(:put, 'https://vagrantcloud.com/api/v1/box/my-acc/my-box/version/1.2/release')
          .to_return(status: 200, body: JSON.dump({}))

        version = VagrantCloud::Version.new(box, '1.2')
        version.release
      end

      it 'sends a PUT request for one off versions' do
        stub_request(:put, 'https://vagrantcloud.com/api/v1/box/hashicorp/precise64/version/1.2.3/release')
          .to_return(status: 200, body: JSON.dump({}))

        version = VagrantCloud::Version.new(box, '1.2')
        version.release('hashicorp', 'precise64', '1.2.3')
      end
    end

    describe '.revoke' do
      it 'sends a PUT request' do
        stub_request(:put, 'https://vagrantcloud.com/api/v1/box/my-acc/my-box/version/1.2/revoke')
          .to_return(status: 200, body: JSON.dump({}))

        version = VagrantCloud::Version.new(box, '1.2')
        version.revoke
      end

      it 'sends a PUT request for one-off versions' do
        stub_request(:put, 'https://vagrantcloud.com/api/v1/box/hashicorp/precise64/version/1.2.3/revoke')
          .to_return(status: 200, body: JSON.dump({}))

        version = VagrantCloud::Version.new(box, '1.2')
        version.revoke('hashicorp', 'precise64', '1.2.3')
      end
    end

    describe '.create_provider' do
      it 'sends a POST request and returns the right instance' do
        result = { 'foo' => 'foo' }
        stub_request(:post, 'https://vagrantcloud.com/api/v1/box/my-acc/my-box/version/1.2/providers').with(
          body: {
            provider: { name: 'my-prov', url: 'http://example.com' }
          }
        ).to_return(status: 200, body: JSON.dump(result))

        version = VagrantCloud::Version.new(box, '1.2')
        provider = version.create_provider('my-prov', 'http://example.com')

        expect(provider).to be_a(Provider)
        expect(provider.data).to eq(result)
      end

      it 'sends a POST request without a provider_url and creates an instance' do
        result = { 'foo' => 'foo' }
        stub_request(:post, 'https://vagrantcloud.com/api/v1/box/my-acc/my-box/version/1.2/providers').with(
          body: { provider: { name: 'my-prov' } }
        ).to_return(status: 200, body: JSON.dump(result))

        provider = VagrantCloud::Version.new(box, '1.2').create_provider('my-prov')
        expect(provider).to be_a(Provider)
        expect(provider.data).to eq(result)
      end
    end

    describe '.ensure_provider' do
      it 'creates nonexisting providers' do
        version = VagrantCloud::Version.new(box, '1.2')
        provider_created = Provider.new(version, 'my-prov', 'original_url' => 'http://example.com')
        expect(version).to receive(:providers).and_return([])
        expect(version).to receive(:create_provider).with('my-prov', 'http://example.com').and_return(provider_created)

        provider = version.ensure_provider('my-prov', 'http://example.com')
        expect(provider).to eq(provider_created)
      end

      it 'returns existing providers' do
        version = VagrantCloud::Version.new(box, '1.2')
        provider_requested = Provider.new(version, 'my-prov', 'original_url' => 'http://example.com')
        expect(version).to receive(:providers).and_return([provider_requested])

        provider = version.ensure_provider('my-prov', 'http://example.com')
        expect(provider).to eq(provider_requested)
      end

      it 'updates existing providers' do
        version = VagrantCloud::Version.new(box, '1.2')
        provider_requested = Provider.new(version, 'my-prov', 'original_url' => 'http://example.com')
        expect(version).to receive(:providers).and_return([provider_requested])
        expect(provider_requested).to receive(:update).with('http://example2.com')

        provider = version.ensure_provider('my-prov', 'http://example2.com')
        expect(provider).to eq(provider_requested)
      end
    end

    describe '.create_version_path' do
      it 'returns a path to create a version with the given objects attributes' do
        data = { 'version' => '1.2', 'description_markdown' => 'desc-markdown', 'status' => 'unreleased' }
        version = VagrantCloud::Version.new(box, '1.2', data)
        expect(version.send(:create_version_path)).to eq('/box/my-acc/my-box/versions')
      end

      it 'returns a path to create a version for a one off version' do
        data = { 'version' => '1.2', 'description_markdown' => 'desc-markdown', 'status' => 'unreleased' }
        version = VagrantCloud::Version.new(box, '1.2', data)
        expect(version.send(:create_version_path, 'hashicorp', 'precise64'))
          .to eq('/box/hashicorp/precise64/versions')
      end
    end

    describe '.version_path' do
      it 'returns a path to create a version with the given objects attributes' do
        data = { 'version' => '1.2', 'description_markdown' => 'desc-markdown', 'status' => 'unreleased' }
        version = VagrantCloud::Version.new(box, '1.2', data)
        expect(version.send(:version_path)).to eq('/box/my-acc/my-box/version/1.2')
      end

      it 'returns a path to create a version for a one off version' do
        data = { 'version' => '1.2', 'description_markdown' => 'desc-markdown', 'status' => 'unreleased' }
        version = VagrantCloud::Version.new(box, '1.2', data)
        expect(version.send(:version_path, 'hashicorp', 'precise64', '2.2'))
          .to eq('/box/hashicorp/precise64/version/2.2')
      end
    end
  end
end
