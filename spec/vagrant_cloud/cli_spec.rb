require 'spec_helper'
require 'vagrant_cloud'

module VagrantCloud
  describe Cli do
    subject { described_class.start(argv) }
    let(:account) { double('account', get_box: box) }
    let(:box) { double('box', create_version: version, get_version: version, versions: [version]) }
    let(:version) { double('version', version: version_number, status: 'unreleased', create_provider: provider, get_provider: provider, release: true) }
    let(:version_number) { '1.2.1' }
    let(:provider) { double('provider', upload_url: upload_url, upload_file: {}, data: provider_data) }
    let(:upload_url) { 'http://example.org/fake_upload_endpoint' }
    let(:provider_data) do
      {
        'name' => 'virtualbox'
      }
    end

    let(:argv) do
      [
        command,
        '--username',
        'username',
        '--token',
        'token',
        '--box',
        'box',
        '--version',
        version_number,
        '--no-verbose'
      ]
    end

    before(:each) do
      allow(VagrantCloud::Account).to receive(:new).and_return(account)
    end

    describe '.create_version' do
      let(:command) { 'create_version' }
      it { is_expected.to eq(version) }
      it 'has the correct version number' do
        expect(subject.version).to eq(version_number)
      end
    end

    describe '.release_version' do
      let(:command) { 'release_version' }
      it { is_expected.to eq(true) }
    end

    describe '.create_provider' do
      let(:command) { 'create_provider' }
      let(:provider_url) { 'http://example.org/file.box' }

      it { is_expected.to eq(provider) }
    end

    describe '.upload_file' do
      let(:command) { 'upload_file' }

      context 'when --provider_file_path provided' do
        before(:each) do
          argv.push('--provider_file_path', './example.box')
        end

        it 'uploads a file to an existing provider' do
          expect(provider).to receive(:upload_file)
          subject
        end
      end

      context 'when --provider_file_path not provided' do
        it 'uploads a file to an existing provider' do
          expect(provider).not_to receive(:upload_file)
          expect { subject }.to output(/No value provided for required options \'--provider-file-path\'/).to_stderr
        end
      end
    end
  end
end
