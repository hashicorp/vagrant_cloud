require 'spec_helper'
require 'vagrant_cloud'

describe VagrantCloud::Account do
  let(:access_token) { double("access_token") }
  let(:client) { double("client", access_token: access_token) }
  let(:username) { double("username") }

  let(:subject) { described_class.new(access_token: access_token) }

  before do
    allow(VagrantCloud::Client).to receive(:new).with(hash_including(access_token: access_token)).and_return(client)
    expect(client).to receive(:request).with(path: "authenticate").
      and_return(user: {username: username})
  end

  describe "#initialize" do
    it "should support a custom server" do
      expect(VagrantCloud::Client).to receive(:new).with(hash_including(url_base: "example.com"))
      described_class.new(access_token: access_token, custom_server: "example.com")
    end

    it "should support retry count" do
      expect(VagrantCloud::Client).to receive(:new).with(hash_including(retry_count: 1))
      described_class.new(access_token: access_token, retry_count: 1)
    end

    it "should support retry interval" do
      expect(VagrantCloud::Client).to receive(:new).with(hash_including(retry_interval: 1))
      described_class.new(access_token: access_token, retry_interval: 1)
    end

    it "should support custom instrumentor" do
      i = double("instrumentor")
      expect(VagrantCloud::Client).to receive(:new).with(hash_including(instrumentor: i))
      described_class.new(access_token: access_token, instrumentor: i)
    end

    it "should set the username during initialization" do
      expect(subject.username).to eq(username)
    end
  end

  describe "#searcher" do
    it "should create a new Searcher instance" do
      expect(subject.searcher).to be_a(VagrantCloud::Search)
    end

    it "should be attached to the account" do
      expect(subject.searcher.account).to eq(subject)
    end
  end

  describe "#create_token" do
    let(:password) { double("password") }
    let(:response) { {token: token, token_hash: token_hash,
      created_at: created_at, description: description} }
    let(:token) { "TOKEN" }
    let(:token_hash) { "TOKEN_HASH" }
    let(:created_at) { "CREATED_AT" }
    let(:description) { "DESCRIPTION" }

    before { allow(client).to receive(:authentication_token_create).and_return(response) }

    it "should require a password" do
      expect { subject.create_token }.to raise_error(ArgumentError)
    end

    it "should return a create token response" do
      expect(subject.create_token(password: password)).
        to be_an_instance_of(VagrantCloud::Response::CreateToken)
    end

    it "should send username and password" do
      expect(client).to receive(:authentication_token_create).with(hash_including(username: username, password: password)).
        and_return(response)
      subject.create_token(password: password)
    end

    it "should send description and two factor code if provided" do
      expect(client).to receive(:authentication_token_create).with(hash_including(description: description, code: "CODE")).
        and_return(response)
      subject.create_token(password: password,
        description: description, code: "CODE")
    end
  end

  describe "#delete_token" do
    it "should send DELETE request to authenticate" do
      expect(client).to receive(:authentication_token_delete)
      subject.delete_token
    end

    it "should return itself" do
      allow(client).to receive(:authentication_token_delete)
      expect(subject.delete_token).to eq(subject)
    end
  end

  describe "#validate_token" do
    it "should call authenticate" do
      expect(client).to receive(:request).with(path: "authenticate")
      subject.validate_token
    end

    it "should return self" do
      allow(client).to receive(:request)
      expect(subject.validate_token).to eq(subject)
    end
  end

  describe "#request_2fa_code" do
    let(:delivery_method) { double("delivery_method") }
    let(:password) { double("password") }
    let(:response) { {two_factor: {obfuscated_destination: "2fa-dst"}} }

    before { allow(client).to receive(:authentication_request_2fa_code).and_return(response) }

    it "should require delivery method" do
      expect { subject.request_2fa_code(password: password)}.
        to raise_error(ArgumentError)
    end

    it "should require password" do
      expect { subject.request_2fa_code(delivery_method: delivery_method) }.
        to raise_error(ArgumentError)
    end

    it "should return a 2FA request response" do
      expect(subject.request_2fa_code(delivery_method: delivery_method, password: password)).
        to be_an_instance_of(VagrantCloud::Response::Request2FA)
    end

    it "should include 2FA request information" do
      expect(client).to receive(:authentication_request_2fa_code).with(hash_including(username: username, password: password, delivery_method: delivery_method)).
        and_return(response)
      subject.request_2fa_code(delivery_method: delivery_method, password: password)
    end

    it "should make a post request to the request code path" do
      expect(client).to receive(:authentication_request_2fa_code).with(hash_including(username: username, password: password, delivery_method: delivery_method)).
        and_return(response)
      subject.request_2fa_code(delivery_method: delivery_method, password: password)
    end
  end

  describe "#organization" do
    let(:response) { {username: r_username} }
    let(:r_username) { "R_USERNAME" }
    let(:username) { "username" }

    before { allow(client).to receive(:organization_get).and_return(response) }

    it "should request account username organization by default" do
      expect(client).to receive(:organization_get).with(name: username).
        and_return(response)
      subject.organization
    end

    it "should request organization with given name" do
      expect(client).to receive(:organization_get).with(name: r_username).
        and_return(response)
      subject.organization(name: r_username)
    end

    it "should return an organization instance" do
      expect(subject.organization).to be_an_instance_of(VagrantCloud::Organization)
    end

    it "should set the account into the organization instance" do
      expect(subject.organization.account).to eq(subject)
    end
  end

  describe "#setup!" do
    let(:response) { {user: {username: different_username}} }
    let(:different_username) { double("different_username") }

    before { allow(client).to receive(:request).with(path: "authenticate").
        and_return(response) }

    it "should make a request to authenticate" do
      expect(client).to receive(:request).with(path: "authenticate").and_return(response)
      subject.send(:setup!)
    end

    it "should extract the username" do
      expect(subject.send(:setup!)).to eq(different_username)
    end

    context "when client is built without access token" do
      let(:c) { double("empty_client", access_token: nil) }
      let(:instance) { described_class.new(access_token: nil) }

      before do
        subject
        allow(VagrantCloud::Client).to receive(:new).with(hash_including(access_token: nil)).
          and_return(c)
      end

      it "should not fetch the token username" do
        expect(c).not_to receive(:request).with(path: "authenticate")
        expect(instance.send(:setup!)).to be_nil
      end
    end
  end
end
