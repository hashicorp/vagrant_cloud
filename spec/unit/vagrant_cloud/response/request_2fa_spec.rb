# Copyright IBM Corp. 2014, 2025
# SPDX-License-Identifier: MIT

require 'spec_helper'
require 'vagrant_cloud'

describe VagrantCloud::Response::Request2FA do
  let(:subject) { described_class.new(destination: destination) }
  let(:destination) { "value" }

  describe "#initialize" do
    it "should create a new instance" do
      expect { subject }.not_to raise_error
    end

    it "should error if destination is not provided" do
      expect { described_class.new }.to raise_error(ArgumentError)
    end
  end

  describe "#destination" do
    it "should return a value" do
      expect(subject.destination).to eq(destination)
    end

    it "should freeze the value" do
      expect(subject.destination).to be_frozen
    end
  end
end
