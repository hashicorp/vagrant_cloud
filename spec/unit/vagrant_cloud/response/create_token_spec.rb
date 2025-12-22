# Copyright IBM Corp. 2014, 2025
# SPDX-License-Identifier: MIT

require 'spec_helper'
require 'vagrant_cloud'

describe VagrantCloud::Response::CreateToken do
  let(:token) { "token" }
  let(:token_hash) { "token_hash" }
  let(:created_at) { Time.now.to_s }
  let(:description) { "description" }

  let(:args) { {token: token, token_hash: token_hash,
    created_at: created_at, description: description } }
  let(:subject) { described_class.new(**args) }

  describe "#initialize" do
    it "should create a new instance" do
      expect { subject }.not_to raise_error
    end

    it "should require token" do
      args.delete(:token)
      expect { subject }.to raise_error(ArgumentError)
    end

    it "should require token_hash" do
      args.delete(:token_hash)
      expect { subject }.to raise_error(ArgumentError)
    end

    it "should require created_at" do
      args.delete(:created_at)
      expect { subject }.to raise_error(ArgumentError)
    end

    it "should require description" do
      args.delete(:description)
      expect { subject }.to raise_error(ArgumentError)
    end
  end

  describe "#token" do
    it "should return a value" do
      expect(subject.token).to eq(token)
    end

    it "should freeze the value" do
      expect(subject.token).to be_frozen
    end
  end

  describe "#token_hash" do
    it "should return a value" do
      expect(subject.token_hash).to eq(token_hash)
    end

    it "should freeze the value" do
      expect(subject.token_hash).to be_frozen
    end
  end

  describe "#created_at" do
    it "should return a value" do
      expect(subject.created_at).to eq(created_at)
    end

    it "should freeze the value" do
      expect(subject.created_at).to be_frozen
    end
  end

  describe "#description" do
    it "should return a value" do
      expect(subject.description).to eq(description)
    end

    it "should freeze the value" do
      expect(subject.description).to be_frozen
    end
  end
end
