# Copyright IBM Corp. 2014, 2025
# SPDX-License-Identifier: MIT

require 'spec_helper'
require 'vagrant_cloud'

describe VagrantCloud::Box do
  let(:organization) { VagrantCloud::Organization.new(account: account, username: organization_name) }
  let(:organization_name) { "ORG_NAME" }
  let(:account) { double("account") }
  let(:name) { "BOX_NAME" }

  let(:subject) { described_class.new(organization: organization, name: name) }

  before do
    allow(account).to receive_message_chain(:client, :box_get).and_return(versions: [])
  end

  describe "#initialize" do
    it "should require a name" do
      expect { described_class.new(organization: organization) }.
        to raise_error(ArgumentError)
    end

    it "should require an organization" do
      expect { described_class.new(name: name) }.
        to raise_error(ArgumentError)
    end

    it "should create new instance with organization and name" do
      expect { described_class.new(name: name, organization: organization) }.
        not_to raise_error
    end
  end

  describe "#short_description" do
    it "should be mutable" do
      expect(subject.short_description).to be_nil
      subject.short_description = "test"
      expect(subject.short_description).to eq("test")
    end
  end

  describe "#description" do
    it "should be mutable" do
      expect(subject.description).to be_nil
      subject.description = "test"
      expect(subject.description).to eq("test")
    end
  end

  describe "#private" do
    it "should be mutable" do
      expect(subject.private).to be_nil
      subject.private = true
      expect(subject.private).to be_truthy
    end
  end

  describe "#delete" do
    it "should return nil" do
      expect(subject.delete).to be_nil
    end

    it "should not request to delete box that does not exist" do
      expect(organization).not_to receive(:account)
      subject.delete
    end

    context "when box exists" do
      before { allow(subject).to receive(:exist?).and_return(true) }

      it "should request box deletion" do
        expect(account).to receive_message_chain(:client, :box_delete)
        subject.delete
      end
    end
  end

  describe "#add_version" do
    it "should create a new version" do
      expect(subject.add_version("1.0.0")).to be_a(VagrantCloud::Box::Version)
    end

    it "should add new version to the versions collection" do
      v = subject.add_version("1.0.0")
      expect(subject.versions).to include(v)
    end

    it "should error when adding an existing version" do
      subject.add_version("1.0.0")
      expect { subject.add_version("1.0.0") }.
        to raise_error(VagrantCloud::Error::BoxError::VersionExistsError)
    end
  end

  describe "#dirty?" do
    it "should be true when box does not exist" do
      expect(subject.exist?).to be_falsey
      expect(subject.dirty?).to be_truthy
    end

    context "when box exists" do
      before { allow(subject).to receive(:exist?).and_return(true) }

      it "should be false" do
        expect(subject.dirty?).to be_falsey
      end

      context "when attribute is modified" do
        before { subject.description = "test" }

        it "should be true" do
          expect(subject.dirty?).to be_truthy
        end

        it "should be true on attribute name check" do
          expect(subject.dirty?(:description)).to be_truthy
        end
      end

      context "deep check" do
        it "should be false" do
          expect(subject.dirty?(deep: true)).to be_falsey
        end

        context "when a version is added" do
          before { subject.add_version("1.0.0") }

          it "should be true" do
            expect(subject.dirty?(deep: true)).to be_truthy
          end
        end
      end
    end
  end

  describe "#exist?" do
    it "should be false when created_at is unset" do
      expect(subject.created_at).to be_falsey
      expect(subject.exist?).to be_falsey
    end

    context "when created_at is set" do
      before { subject.clean(data: {created_at: Time.now.to_s}) }

      it "should be true" do
        expect(subject.exist?).to be_truthy
      end
    end
  end

  describe "#versions_on_demand" do
    context "when box exists" do
      before { allow(subject).to receive(:exist?).and_return(true) }

      it "should load versions when called" do
        expect(account).to receive_message_chain(:client, :box_get).and_return(versions: [])
        subject.versions_on_demand
      end

      it "should not load versions after initial load" do
        expect(subject.dirty?(:versions)).to be_falsey
        expect(account).to receive_message_chain(:client, :box_get).and_return(versions: [])
        subject.versions_on_demand
        expect(account).not_to receive(:client)
        subject.versions_on_demand
      end
    end

    context "when box does not exist" do
      before { allow(subject).to receive(:exist?).and_return(false) }

      it "should not load versions when called" do
        expect(account).not_to receive(:client)
        subject.versions_on_demand
      end

      it "should not load versions after initial load" do
        expect(subject.dirty?(:versions)).to be_falsey
        expect(account).not_to receive(:client)
        subject.versions_on_demand
        expect(account).not_to receive(:client)
        subject.versions_on_demand
      end
    end
  end

  describe "#save" do
    before do
      allow(subject).to receive(:save_versions)
      allow(subject).to receive(:save_box)
    end

    it "should return self" do
      expect(subject.save).to eq(subject)
    end

    context "when box does not exist" do
      before { allow(subject).to receive(:exist?).and_return(false) }

      it "should save the box" do
        expect(subject).to receive(:save_box).ordered
        expect(subject).to receive(:save_versions).ordered
        subject.save
      end
    end

    context "when box includes unsaved versions" do
      before { subject.add_version("1.0.0") }

      it "should save the versions" do
        expect(subject).to receive(:save_versions)
        subject.save
      end
    end

    context "when box exists" do
      before { allow(subject).to receive(:exist?).and_return(true) }

      it "should not save anything" do
        expect(subject).not_to receive(:save_box)
        expect(subject).not_to receive(:save_versions)
        subject.save
      end

      context "when box includes unsaved versions" do
        before { subject.add_version("1.0.0") }
  
        it "should save the versions" do
          expect(subject).to receive(:save_versions)
          subject.save
        end
      end

      context "when box attribute is updated" do
        before { subject.description = "test" }

        it "should save the box" do
          expect(subject).to receive(:save_box)
          subject.save
        end
      end
    end
  end

  describe "#save_box" do
    context "when box exists" do
      before { allow(subject).to receive(:exist?).and_return(true) }

      it "should return self" do
        expect(account).to receive_message_chain(:client, :box_update).and_return({})
        expect(subject.send(:save_box)).to eq(subject)
      end

      it "should request a box update" do
        expect(account).to receive_message_chain(:client, :box_update).and_return({})
        subject.send(:save_box)
      end

      it "should include the organization name" do
        expect(account).to receive_message_chain(:client, :box_update).
          with(hash_including(username: organization_name)).and_return({})
        subject.send(:save_box)
      end

      it "should include the name" do
        expect(account).to receive_message_chain(:client, :box_update).
          with(hash_including(name: name)).and_return({})
        subject.send(:save_box)
      end

      it "should include the short description" do
        expect(account).to receive_message_chain(:client, :box_update).
          with(hash_including(short_description: subject.short_description)).and_return({})
        subject.send(:save_box)
      end

      it "should include the description" do
        expect(account).to receive_message_chain(:client, :box_update).
          with(hash_including(description: subject.description)).and_return({})
        subject.send(:save_box)
      end

      it "should include the box privacy" do
        expect(account).to receive_message_chain(:client, :box_update).
          with(hash_including(is_private: subject.private)).and_return({})
        subject.send(:save_box)
      end
    end

    context "when box does not exist" do
      before { allow(subject).to receive(:exist?).and_return(false) }

      it "should request a box create" do
        expect(account).to receive_message_chain(:client, :box_create).and_return({})
        subject.send(:save_box)
      end

      it "should include the organization name" do
        expect(account).to receive_message_chain(:client, :box_create).
          with(hash_including(username: organization_name)).and_return({})
        subject.send(:save_box)
      end

      it "should include the name" do
        expect(account).to receive_message_chain(:client, :box_create).
          with(hash_including(name: name)).and_return({})
        subject.send(:save_box)
      end

      it "should include the short description" do
        expect(account).to receive_message_chain(:client, :box_create).
          with(hash_including(short_description: subject.short_description)).and_return({})
        subject.send(:save_box)
      end

      it "should include the description" do
        expect(account).to receive_message_chain(:client, :box_create).
          with(hash_including(description: subject.description)).and_return({})
        subject.send(:save_box)
      end

      it "should include the box privacy" do
        expect(account).to receive_message_chain(:client, :box_create).
          with(hash_including(is_private: subject.private)).and_return({})
        subject.send(:save_box)
      end
    end
  end

  describe "#save_versions" do
    it "should return self" do
      expect(subject.send(:save_versions)).to eq(subject)
    end

    it "should call save on any versions" do
      subject.add_version("1.0.0")
      expect(account).to receive_message_chain(:client, :box_version_create).
        and_return({})
      subject.send(:save_versions)
    end
  end
end
