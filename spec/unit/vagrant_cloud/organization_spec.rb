# Copyright IBM Corp. 2014, 2025
# SPDX-License-Identifier: MIT

require "spec_helper"
require "vagrant_cloud"

describe VagrantCloud::Organization do
  let(:account) { double("account") }
  let(:username) { "USERNAME" }

  let(:subject) { described_class.new(account: account, username: username) }

  describe "#initialize" do
    it "should error if account is not provided" do
      expect { described_class.new(username: username) }.to raise_error(ArgumentError)
    end

    it "should error if username is not provided" do
      expect { described_class.new(account: account) }.to raise_error(ArgumentError)
    end
  end

  describe "#add_box" do
    it "should create a new box" do
      expect(subject.add_box("test")).to be_a(VagrantCloud::Box)
    end

    it "should add box to the collection" do
      expect(subject.boxes).to be_empty
      subject.add_box("test")
      expect(subject.boxes).not_to be_empty
    end

    it "should error if box name already exists" do
      subject.add_box("test")
      expect { subject.add_box("test") }.
        to raise_error(VagrantCloud::Error::BoxError::BoxExistsError)
    end
  end

  describe "#dirty?" do
    it "should return false by default" do
      expect(subject.dirty?).to be_falsey
    end

    it "should check dirtiness based on attribute" do
      expect(subject.dirty?(:username)).to be_falsey
    end

    context "deep check" do
      it "should return false by default" do
        expect(subject.dirty?(deep: true)).to be_falsey
      end

      context "with box collection of one clean box" do
        before do
          b = subject.add_box("test")
          b.clean(data: {created_at: Time.now.to_s})
          subject.clean!
        end

        it "should return false" do
          expect(subject.dirty?(deep: true)).to be_falsey
        end

        context "with a dirty box in collection" do
          before { subject.add_box("test2") }

          it "should return true" do
            expect(subject.dirty?(deep: true)).to be_truthy
          end
        end
      end
    end
  end

  describe "#save" do
    it "should return self" do
      expect(subject.save).to eq(subject)
    end

    context "with boxes" do
      it "should save boxes" do
        b = subject.add_box("test")
        expect(b).to receive(:save)
        subject.save
      end
    end
  end
end
