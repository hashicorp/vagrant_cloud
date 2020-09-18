require 'spec_helper'
require 'vagrant_cloud'

describe VagrantCloud::Box::Provider do
  let(:version) { double("version") }
  let(:provider_name) { "PROVIDER_NAME" }
  let(:box_username) { double("box_username") }
  let(:box_name) { double("box_name") }
  let(:version_version) { double("version_version") }


  let(:subject) { described_class.new(version: version, name: provider_name) }

  before do
    allow(version).to receive(:is_a?).with(VagrantCloud::Box::Version).and_return(true)
    allow(version).to receive_message_chain(:box, :username).and_return(box_username)
    allow(version).to receive_message_chain(:box, :name).and_return(box_name)
    allow(version).to receive(:version).and_return(version_version)
  end

  describe "#initialize" do
    it "should require a version" do
      expect { described_class.new(name: provider_name) }.to raise_error(ArgumentError)
    end

    it "should require a name" do
      expect { described_class.new(version: version) }.to raise_error(ArgumentError)
    end
  end

  describe "#delete" do
    context "when provdier does not exist" do
      before { allow(subject).to receive(:exist?).and_return(false) }

      it "should not request deletion" do
        expect(version).not_to receive(:box)
        subject.delete
      end

      it "should return nil" do
        expect(subject.delete).to be_nil
      end
    end

    context "when provider does exist" do
      before do
        allow(subject).to receive(:exist?).and_return(true)
        allow(version).to receive_message_chain(:providers, :delete)
      end

      it "should request deletion" do
        expect(version).to receive_message_chain(:box, :organization, :account, :client, :box_version_provider_delete)
        subject.delete
      end

      it "should send box username" do
        expect(version).to receive_message_chain(:box, :organization, :account, :client, :box_version_provider_delete).
          with(hash_including(username: box_username))
        subject.delete
      end

      it "should send box name" do
        expect(version).to receive_message_chain(:box, :organization, :account, :client, :box_version_provider_delete).
          with(hash_including(name: box_name))
        subject.delete
      end

      it "should send version number" do
        expect(version).to receive_message_chain(:box, :organization, :account, :client, :box_version_provider_delete).
          with(hash_including(version: version_version))
        subject.delete
      end

      it "should send provider_name" do
        expect(version).to receive_message_chain(:box, :organization, :account, :client, :box_version_provider_delete).
          with(hash_including(provider: provider_name))
        subject.delete
      end

      it "should return nil" do
        expect(version).to receive_message_chain(:box, :organization, :account, :client, :box_version_provider_delete)
        expect(subject.delete).to be_nil
      end

      it "should remove itself from the versions provider collection" do
        expect(version).to receive_message_chain(:box, :organization, :account, :client, :box_version_provider_delete)
        expect(version).to receive_message_chain(:providers, :delete).with(subject)
        subject.delete
      end
    end
  end

  describe "#upload" do
    let(:response) { {upload_path: upload_path} }
    let(:response_direct) { {upload_path: upload_path, callback: callback} }
    let(:upload_path) { double("upload_path") }
    let(:callback) { double("callback") }

    before do
      allow(version).to receive_message_chain(:box, :organization, :account, :client, :box_version_provider_upload).
        and_return(response)
      allow(version).to receive_message_chain(:box, :organization, :account, :client, :box_version_provider_upload_direct).
        and_return(response_direct)
      allow(version).to receive_message_chain(:box, :tag).and_return("org/box")
      allow(version).to receive(:version).and_return("1.0")
    end

    context "when provider does not exist" do
      before { allow(subject).to receive(:exist?).and_return(false) }

      it "should error" do
        expect { subject.upload }.to raise_error(VagrantCloud::Error::BoxError::ProviderNotFoundError)
      end

      context "when direct upload is enabled" do
        it "should error" do
          expect { subject.upload(direct: true) }.
            to raise_error(VagrantCloud::Error::BoxError::ProviderNotFoundError)
        end
      end
    end

    context "when provider exists" do
      before { allow(subject).to receive(:exist?).and_return(true) }

      it "should error if path and block are both provided" do
        expect { subject.upload(path: "/") {} }.to raise_error(ArgumentError)
      end

      it "should return the upload path" do
        expect(subject.upload).to eq(upload_path)
      end

      context "with path provided" do
        let(:path) { "PATH" }

        before { allow(File).to receive(:open).with(path, any_args) }

        context "when path does not exist" do
          before { allow(File).to receive(:exist?).with(path).and_return(false) }

          it "should error" do
            expect { subject.upload(path: path) }.to raise_error(Errno::ENOENT)
          end
        end

        context "when path does exist" do
          before { allow(File).to receive(:exist?).with(path).and_return(true) }

          it "should make request for upload" do
            expect(version).to receive_message_chain(:box, :organization, :account, :client, :box_version_provider_upload).
              and_return(response)
            subject.upload(path: path)
          end

          it "should upload the path" do
            expect(File).to receive(:open).with(path, any_args).and_yield(double("file"))
            expect(Excon).to receive(:put).with(upload_path, any_args)
            subject.upload(path: path)
          end

          it "should return self" do
            expect(subject.upload(path: path)).to eq(subject)
          end
        end
      end

      context "with block provided" do
        it "should make request for upload" do
          expect(version).to receive_message_chain(:box, :organization, :account, :client, :box_version_provider_upload).
            and_return(response)
          subject.upload { |url| }
        end

        it "should yield the upload path" do
          subject.upload do |url|
            expect(url).to eq(upload_path)
          end
        end

        it "should return result of block" do
          expect(subject.upload { |u| :test }).to eq(:test)
        end
      end
    end

    context "with direct option set" do
      before do
        allow(subject).to receive(:exist?).and_return(true)
        allow(Excon).to receive(:put)
        allow(Excon).to receive(:post)
      end

      it "should error if path and block are both provided" do
        expect { subject.upload(path: "/", direct: true) {} }.to raise_error(ArgumentError)
      end

      it "should return a DirectUpload" do
        expect(subject.upload(direct: true)).to be_a(VagrantCloud::Box::Provider::DirectUpload)
      end

      it "should include an upload_url and callback_url in result" do
        result = subject.upload(direct: true)
        expect(result.upload_url).to eq(upload_path)
        expect(result.callback_url).to eq(callback)
      end

      context "with path provided" do
        let(:path) { "PATH" }

        before { allow(File).to receive(:open).with(path, any_args) }

        context "when path does not exist" do
          before { allow(File).to receive(:exist?).with(path).and_return(false) }

          it "should error" do
            expect { subject.upload(path: path, direct: true) }.to raise_error(Errno::ENOENT)
          end
        end

        context "when path does exist" do
          before { allow(File).to receive(:exist?).with(path).and_return(true) }

          it "should make request for direct upload" do
            expect(version).to receive_message_chain(:box, :organization, :account, :client, :box_version_provider_upload_direct).
              and_return(response_direct)
            subject.upload(path: path, direct: true)
          end

          it "should upload the path" do
            expect(File).to receive(:open).with(path, any_args).and_yield(double("file"))
            expect(Excon).to receive(:post).with(upload_path, any_args)
            subject.upload(path: path, direct: true)
          end

          it "should request the callback" do
            expect(Excon).to receive(:put).with(callback)
            subject.upload(path: path, direct: true)
          end

          it "should return self" do
            expect(subject.upload(path: path, direct: true)).to eq(subject)
          end
        end
      end

      context "with block provided" do
        it "should make request for upload" do
          expect(version).to receive_message_chain(:box, :organization, :account, :client, :box_version_provider_upload_direct).
            and_return(response_direct)
          subject.upload(direct: true) { |du| }
        end

        it "should yield the upload path" do
          subject.upload(direct: true) do |du|
            expect(du).to eq(upload_path)
          end
        end

        it "should request the callback" do
          expect(Excon).to receive(:put).with(callback)
          subject.upload(direct: true) {|_|}
        end

        it "should return result of block" do
          expect(subject.upload(direct: true) { |du| :test }).to eq(:test)
        end
      end
    end
  end

  describe "#exist?" do
    let(:subject) { described_class.new(version: version, name: provider_name, created_at: created_at) }

    context "with created_at attribute set" do
      let(:created_at) { Time.now.to_s }

      it "should be true" do
        expect(subject.exist?).to be_truthy
      end
    end

    context "with created_at attribute unset" do
      let(:created_at) { nil }

      it "should be false" do
        expect(subject.exist?).to be_falsey
      end
    end
  end

  describe "#dirty?" do
    context "when provider does not exist" do
      before { allow(subject).to receive(:exist?).and_return(false) }

      it "should be true" do
        expect(subject.dirty?).to be_truthy
      end
    end

    context "when provider does exist" do
      before { allow(subject).to receive(:exist?).and_return(true) }

      it "should be false" do
        expect(subject.dirty?).to be_falsey
      end

      context "with modified attribute" do
        before { subject.url = "test" }

        it "should be true" do
          expect(subject.dirty?).to be_truthy
        end
      end
    end
  end

  describe "#save" do
    before { allow(subject).to receive(:save_provider) }

    context "when provider is not dirty" do
      before { allow(subject).to receive(:dirty?).and_return(false) }

      it "should not save provider" do
        expect(subject).not_to receive(:save_provider)
        subject.save
      end

      it "should return self" do
        expect(subject.save).to eq(subject)
      end
    end

    context "when provider is dirty" do
      before { allow(subject).to receive(:dirty?).and_return(true) }

      it "should save the provider" do
        expect(subject).to receive(:save_provider)
        subject.save
      end

      it "should return self" do
        expect(subject.save).to eq(subject)
      end
    end
  end

  describe "#save_provider" do
    before do
      allow(version).to receive_message_chain(:box, :organization, :account, :client, :box_version_provider_create).
        and_return({})
      allow(version).to receive_message_chain(:box, :organization, :account, :client, :box_version_provider_update).
        and_return({})
    end

    context "when provider exists" do
      before { allow(subject).to receive(:exist?).and_return(true) }

      it "should request an update" do
        expect(version).to receive_message_chain(:box, :organization, :account, :client, :box_version_provider_update).
          and_return({})
        subject.send(:save_provider)
      end

      it "should return self" do
        expect(subject.send(:save_provider)).to eq(subject)
      end

      it "should include box organization" do
        expect(version).to receive_message_chain(:box, :organization, :account, :client, :box_version_provider_update).
          with(hash_including(username: box_username)).and_return({})
        subject.send(:save_provider)
      end

      it "should include box name" do
        expect(version).to receive_message_chain(:box, :organization, :account, :client, :box_version_provider_update).
          with(hash_including(name: box_name)).and_return({})
        subject.send(:save_provider)
      end

      it "should include version" do
        expect(version).to receive_message_chain(:box, :organization, :account, :client, :box_version_provider_update).
          with(hash_including(version: version_version)).and_return({})
        subject.send(:save_provider)
      end

      it "should include provider" do
        expect(version).to receive_message_chain(:box, :organization, :account, :client, :box_version_provider_update).
          with(hash_including(provider: provider_name)).and_return({})
        subject.send(:save_provider)
      end

      it "should include checksum" do
        expect(version).to receive_message_chain(:box, :organization, :account, :client, :box_version_provider_update).
          with(hash_including(checksum: subject.checksum)).and_return({})
        subject.send(:save_provider)
      end

      it "should inclufde checksum_type" do
        expect(version).to receive_message_chain(:box, :organization, :account, :client, :box_version_provider_update).
          with(hash_including(checksum_type: subject.checksum_type)).and_return({})
        subject.send(:save_provider)
      end
    end

    context "when provider does not exist" do
      before { allow(subject).to receive(:exist?).and_return(false) }

      it "should request a creation" do
        expect(version).to receive_message_chain(:box, :organization, :account, :client, :box_version_provider_create).
          and_return({})
        subject.send(:save_provider)
      end

      it "should return self" do
        expect(subject.send(:save_provider)).to eq(subject)
      end

      it "should include box organization" do
        expect(version).to receive_message_chain(:box, :organization, :account, :client, :box_version_provider_create).
          with(hash_including(username: box_username)).and_return({})
        subject.send(:save_provider)
      end

      it "should include box name" do
        expect(version).to receive_message_chain(:box, :organization, :account, :client, :box_version_provider_create).
          with(hash_including(name: box_name)).and_return({})
        subject.send(:save_provider)
      end

      it "should include version" do
        expect(version).to receive_message_chain(:box, :organization, :account, :client, :box_version_provider_create).
          with(hash_including(version: version_version)).and_return({})
        subject.send(:save_provider)
      end

      it "should include provider" do
        expect(version).to receive_message_chain(:box, :organization, :account, :client, :box_version_provider_create).
          with(hash_including(provider: provider_name)).and_return({})
        subject.send(:save_provider)
      end

      it "should include checksum" do
        expect(version).to receive_message_chain(:box, :organization, :account, :client, :box_version_provider_create).
          with(hash_including(checksum: subject.checksum)).and_return({})
        subject.send(:save_provider)
      end

      it "should inclufde checksum_type" do
        expect(version).to receive_message_chain(:box, :organization, :account, :client, :box_version_provider_create).
          with(hash_including(checksum_type: subject.checksum_type)).and_return({})
        subject.send(:save_provider)
      end
    end
  end
end
