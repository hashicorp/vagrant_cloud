# Copyright IBM Corp. 2014, 2025
# SPDX-License-Identifier: MIT

require 'spec_helper'
require 'vagrant_cloud'

describe VagrantCloud::Box::Version do
  let(:box) { double("box", username: box_username, name: box_name, tag: "#{box_username}/#{box_name}") }
  let(:box_username) { double("box_username") }
  let(:box_name) { double("box_name") }
  let(:version) { "1.0.0" }

  let(:subject) { described_class.new(box: box, version: version) }

  before { allow(box).to receive(:is_a?).with(VagrantCloud::Box).and_return(true) }

  describe "#initialize" do
    it "should require a box" do
      expect { described_class.new }.to raise_error(ArgumentError)
    end

    it "should require box argument be box type" do
      expect { described_class.new(box: nil) }.to raise_error(TypeError)
    end

    it "should load providers" do
      instance = described_class.new(box: box, version: version, providers: [{name: "test"}])
      expect(instance.providers).not_to be_empty
      expect(instance.providers.first).to be_a(VagrantCloud::Box::Provider)
    end
  end

  describe "#delete" do
    before do
      allow(box).to receive(:versions).and_return([])
      allow(box).to receive_message_chain(:organization, :account, :client, :box_version_delete)
    end

    it "should not delete if version does not exist" do
      expect(box).not_to receive(:organization)
      subject.delete
    end

    it "should return nil" do
      expect(subject.delete).to be_nil
    end

    context "when version exists" do
      before do
        allow(subject).to receive(:exist?).and_return(true)
        allow(box).to receive(:clean)
      end

      it "should make a version deletion request" do
        expect(box).to receive_message_chain(:organization, :account, :client, :box_version_delete)
        subject.delete
      end

      it "should include box username and name" do
        expect(box).to receive_message_chain(:organization, :account, :client, :box_version_delete).
          with(hash_including(username: box_username, name: box_name))
        subject.delete
      end

      it "should include the version" do
        expect(box).to receive_message_chain(:organization, :account, :client, :box_version_delete).
          with(hash_including(version: version))
        subject.delete
      end

      it "should delete the version from the box versions" do
        versions = double("versions")
        expect(versions).to receive(:dup).and_return(versions)
        expect(box).to receive(:versions).and_return(versions)
        expect(versions).to receive(:delete).with(subject).and_return(versions)
        expect(box).to receive(:clean).with(data: {versions: versions})
        subject.delete
      end
    end
  end

  describe "#release" do
    context "when version is released" do
      before { allow(subject).to receive(:released?).and_return(true) }

      it "should error" do
        expect { subject.release }.to raise_error(VagrantCloud::Error::BoxError::VersionStatusChangeError)
      end
    end

    context "when version has not been saved" do
      before { allow(subject).to receive(:exist?).and_return(false) }

      it "should error" do
        expect { subject.release }.to raise_error(VagrantCloud::Error::BoxError::VersionStatusChangeError)
      end
    end

    context "when version is saved and not released" do
      before do
        allow(subject).to receive(:exist?).and_return(true)
        allow(subject).to receive(:released?).and_return(false)
      end

      it "should send request to release version" do
        expect(box).to receive_message_chain(:organization, :account, :client, :box_version_release).
          and_return({})
        subject.release
      end

      it "should include box username, box name, and version" do
        expect(box).to receive_message_chain(:organization, :account, :client, :box_version_release).
          with(hash_including(username: box_username, name: box_name, version: version)).and_return({})
        subject.release
      end

      it "should update status with value provided in result" do
        expect(box).to receive_message_chain(:organization, :account, :client, :box_version_release).
          and_return({status: "active"})
        subject.release
        expect(subject.status).to eq("active")
      end

      it "should return self" do
        expect(box).to receive_message_chain(:organization, :account, :client, :box_version_release).
          and_return({})
        expect(subject.release).to eq(subject)
      end
    end
  end

  describe "#revoke" do
    context "when version is not released" do
      before { allow(subject).to receive(:released?).and_return(false) }
      it "should error" do
        expect { subject.revoke }.to raise_error(VagrantCloud::Error::BoxError::VersionStatusChangeError)
      end
    end

    context "when version is released" do
      before { allow(subject).to receive(:released?).and_return(true) }

      it "should send request to revoke release" do
        expect(box).to receive_message_chain(:organization, :account, :client, :box_version_revoke).
          and_return({})
        subject.revoke
      end

      it "should include the box username, box name, and version" do
        expect(box).to receive_message_chain(:organization, :account, :client, :box_version_revoke).
          with(hash_including(username: box_username, name: box_name, version: version)).and_return({})
        subject.revoke
      end

      it "should update status with value provided in result" do
        expect(box).to receive_message_chain(:organization, :account, :client, :box_version_revoke).
          and_return({status: "inactive"})
        subject.revoke
        expect(subject.status).to eq("inactive")
      end

      it "should return self" do
        expect(box).to receive_message_chain(:organization, :account, :client, :box_version_revoke).
          and_return({})
        expect(subject.revoke).to eq(subject)
      end
    end
  end

  describe "#add_provider" do
    it "should create a new provider" do
      expect(subject.add_provider("test")).to be_a(VagrantCloud::Box::Provider)
    end

    it "should add provider to providers collection" do
      pv = subject.add_provider("test")
      expect(subject.providers).to include(pv)
    end

    it "should raise error when provider exists" do
      subject.add_provider("test")
      expect { subject.add_provider("test") }.
        to raise_error(VagrantCloud::Error::BoxError::VersionProviderExistsError)
    end

    context "with architecture" do
      it "should add provider to collection and include architecture" do
        pv = subject.add_provider("test", "test-arch")
        expect(subject.providers).to include(pv)
        expect(pv.architecture).to eq("test-arch")
      end

      it "should add multiple same providers with different architectures" do
        ["arch1", "arch2", "arch3"].each do |arch|
          pv = subject.add_provider("test", arch)
          expect(subject.providers).to include(pv)
          expect(pv.architecture).to eq(arch)
        end
      end

      it "should raise error when provider exists" do
        subject.add_provider("test", "test-arch")
        expect { subject.add_provider("test", "test-arch") }.
          to raise_error(VagrantCloud::Error::BoxError::VersionProviderExistsError)
      end

      it "should raise error when adding existing provider without architecture" do
        subject.add_provider("test", "test-arch")
        expect { subject.add_provider("test") }.
          to raise_error(VagrantCloud::Error::BoxError::VersionProviderExistsError)
      end
    end
  end

  describe "#dirty?" do
    context "when version does not exist" do
      before { allow(subject).to receive(:exist?).and_return(false) }

      it "should be true" do
        expect(subject.dirty?).to be_truthy
      end
    end

    context "when version does exist" do
      before { allow(subject).to receive(:exist?).and_return(true) }

      it "should be false" do
        expect(subject.dirty?).to be_falsey
      end

      context "with modified attribute" do
        before { subject.description = "test" }

        it "should be true" do
          expect(subject.dirty?).to be_truthy
        end
      end

      context "with deep check" do
        it "should be false" do
          expect(subject.dirty?(deep: true)).to be_falsey
        end

        context "with modified attribute" do
          before { subject.description = "test" }

          it "should be true" do
            expect(subject.dirty?(deep: true)).to be_truthy
          end
        end

        context "with dirty provider in providers collection" do
          before { subject.add_provider("test") }

          it "should be true" do
            expect(subject.dirty?(deep: true)).to be_truthy
          end
        end
      end
    end
  end

  describe "#exist?" do
    let(:subject) { described_class.new(box: box, version: version, created_at: created_at) }

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

  describe "#save" do
    before do
      allow(subject).to receive(:save_version)
      allow(subject).to receive(:save_provdiers)
    end

    it "should return self" do
      expect(subject.save).to eq(subject)
    end

    context "when version is dirty" do
      before do
        allow(subject).to receive(:dirty?).and_return(true)
        allow(subject).to receive(:dirty?).with(deep: true).and_return(false)
      end

      it "should save the version" do
        expect(subject).to receive(:save_version)
        subject.save
      end
    end

    context "when version is clean" do
      before { allow(subject).to receive(:dirty?).and_return(false) }

      it "should not save the version" do
        expect(subject).not_to receive(:save_version)
        subject.save
      end
    end

    context "when dirty provider in providers collection" do
      before { subject.add_provider("test") }

      it "should save the providers" do
        expect(subject).to receive(:save_providers)
        subject.save
      end
    end
  end

  describe "#save_version" do
    context "when version exists" do
      before { allow(subject).to receive(:exist?).and_return(true) }

      it "should request a version update" do
        expect(box).to receive_message_chain(:organization, :account, :client, :box_version_update).
          and_return({})
        subject.send(:save_version)
      end

      it "should include the box username, box name, version, and description" do
        expect(box).to receive_message_chain(:organization, :account, :client, :box_version_update).
          with(hash_including(username: box_username, name: box_name, version: version, description: subject.description)).
          and_return({})
        subject.send(:save_version)
      end

      it "should return self" do
        expect(box).to receive_message_chain(:organization, :account, :client, :box_version_update).
          and_return({})
        expect(subject.send(:save_version)).to eq(subject)
      end
    end

    context "when version does not exist" do
      before { allow(subject).to receive(:exist?).and_return(false) }

      it "should request a version create" do
        expect(box).to receive_message_chain(:organization, :account, :client, :box_version_create).
          and_return({})
        subject.send(:save_version)
      end

      it "should include the box username, box name, version, and description" do
        expect(box).to receive_message_chain(:organization, :account, :client, :box_version_create).
          with(hash_including(username: box_username, name: box_name, version: version, description: subject.description)).
          and_return({})
        subject.send(:save_version)
      end

      it "should return self" do
        expect(box).to receive_message_chain(:organization, :account, :client, :box_version_create).
          and_return({})
        expect(subject.send(:save_version)).to eq(subject)
      end
    end
  end

  describe "#save_providers" do
    it "should return self" do
      expect(subject.send(:save_providers)).to eq(subject)
    end

    it "should save the providers" do
      pv = subject.add_provider("test")
      expect(pv).to receive(:save)
      subject.send(:save_providers)
    end
  end
end
