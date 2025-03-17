require 'spec_helper'
require 'vagrant_cloud'

describe VagrantCloud::Client do
  let(:connection) { double("connection", request: nil) }
  let(:oauth_client) { double("oauth", client_credentials: client_credentials) }
  let(:client_credentials) { double("client_credentials", get_token: token) }
  let(:token) { VagrantCloud::Auth::HCPToken.new(token: "stub", expires_at: Time.now.to_i + 100) }

  before do
    allow(OAuth2::Client).to receive(:new).and_return(oauth_client)
  end

  describe "#intialize" do
    context "with no arguments" do
      it "should have #url_base set" do
        expect(subject.url_base).not_to be_nil
      end

      it "should have #retry_count set" do
        expect(subject.retry_count).not_to be_nil
      end

      it "should have #retry_interval set" do
        expect(subject.retry_interval).not_to be_nil
      end

      it "should have #instrumentor set" do
        expect(subject.instrumentor).not_to be_nil
      end
    end

    context "with arguments" do
      it "should set #url_base" do
        subject = described_class.new(url_base: "http://example.com")
        expect(subject.url_base).to eq("http://example.com")
      end

      it "should set #retry_count" do
        subject = described_class.new(retry_count: 1)
        expect(subject.retry_count).to eq(1)
      end

      it "should set #retry_interval" do
        subject = described_class.new(retry_interval: 1)
        expect(subject.retry_interval).to eq(1)
      end

      it "should set #instrumentor" do
        i = double("instrumentor")
        subject = described_class.new(instrumentor: i)
        expect(subject.instrumentor).to eq(i)
      end

      it "should set #access_token" do
        subject = described_class.new(access_token: "token")
        expect(subject.access_token).to eq("token")
      end
    end
  end

  describe "#parse_json" do
    it "should return result with symbolized keys" do
      expect(subject.send(:parse_json, {"test" => :val}.to_json)).to eq({test: "val"})
    end
  end

  describe "#clean_parameters" do
    it "should remove Data::Nil values from Array" do
      val = [1, 2, VagrantCloud::Data::Nil, 3]
      result = subject.send(:clean_parameters, val)
      expect(result).to eq([1, 2, 3])
    end

    it "should remove Data::Nil values from nested Arrays" do
      val = [1, 2, VagrantCloud::Data::Nil, [1, 2, VagrantCloud::Data::Nil], 3]
      result = subject.send(:clean_parameters, val)
      expect(result).to eq([1, 2, [1, 2], 3])
    end

    it "should remove Data::Nil values from Hash" do
      val = {a: 1, b: 2, c: VagrantCloud::Data::Nil, d: 3}
      result = subject.send(:clean_parameters, val)
      expect(result).to eq({a: 1, b: 2, d: 3})
    end

    it "should remove Data::Nil values from nested Hashes" do
      val = {a: 1, b: 2, c: VagrantCloud::Data::Nil, d: {a: 1, b: VagrantCloud::Data::Nil}, e: 3}
      result = subject.send(:clean_parameters, val)
      expect(result).to eq({a: 1, b: 2, d: {a: 1}, e: 3})
    end

    it "should remove Data::Nil values from nested Arrays and Hashes" do
      val = {a: 1, b: [1, 2, VagrantCloud::Data::Nil, {a: 1, b: VagrantCloud::Data::Nil}], c: 2}
      result = subject.send(:clean_parameters, val)
      expect(result).to eq({a: 1, b: [1, 2, {a: 1}], c: 2})
    end
  end

  describe "#with_connection" do
    it "should provide the connection to the block" do
      subject.with_connection do |c|
        expect(c).to be_a(Excon::Connection)
      end
    end

    it "should gate access to the connection" do
      fiber = Fiber.new do
        subject.with_connection { Fiber.yield }
      end
      fiber.resume
      expect { subject.with_connection(wait: false) {} }.
        to raise_error(VagrantCloud::Error::ClientError::ConnectionLockedError)
      fiber.resume
      expect { subject.with_connection {} }.not_to raise_error
    end
  end

  describe "#request" do
    let(:response) { double("response", body: body, status: status) }
    let(:body) { "" }
    let(:status) { 200 }

    before do
      allow(subject).to receive(:with_connection).
        and_yield(connection)
      allow(connection).to receive(:request).
        and_return(response)
    end

    it "should require path to be set" do
      expect { subject.request }.to raise_error(ArgumentError)
    end

    it "should default to GET method" do
      expect(connection).to receive(:request).
        with(hash_including(method: :get)).
        and_return(response)
      subject.request(path: "/")
    end

    it "should use method provided" do
      expect(connection).to receive(:request).
        with(hash_including(method: :post)).
        and_return(response)
      subject.request(path: "/", method: :post)
    end

    it "should set a request ID header" do
      expect(connection).to receive(:request) do |args|
        expect(args.dig(:headers, "X-Request-Id")).not_to be_nil
        response
      end
      subject.request(path: "/")
    end

    context "path prefixing" do
      it "should prefix the v2 API by default" do
        expect(connection).to receive(:request) do |args|
          expect(args[:path]).to start_with(VagrantCloud::Client::API_V2_PATH)
          response
        end
        subject.request(path: "/")
      end

      it "should prefix the v1 API when requested" do
        expect(connection).to receive(:request) do |args|
          expect(args[:path]).to start_with(VagrantCloud::Client::API_V1_PATH)
          response
        end
        subject.request(path: "/", api_version: 1)
      end

      it "should prefix the v2 API when requested" do
        expect(connection).to receive(:request) do |args|
          expect(args[:path]).to start_with(VagrantCloud::Client::API_V2_PATH)
          response
        end
        subject.request(path: "/", api_version: 2)
      end

      it "should not add a prefix if the v1 API prefix already exists" do
        expect(connection).to receive(:request).with(hash_including(path: "/api/v1/test/path"))
        subject.request(path: "/api/v1/test/path")
      end

      it "should not add a prefix if the v2 API prefix already exists" do
        expect(connection).to receive(:request).with(hash_including(path: "/api/v2/test/path"))
        subject.request(path: "/api/v2/test/path")
      end

      context "when base path is defined" do
        let(:base_path) { "/custom/path" }
        subject { described_class.new(url_base: "http://example.com#{base_path}") }

        it "should suffix API to base path" do
          expect(connection).to receive(:request).with(hash_including(path: "#{base_path}/api/v1/test"))
          subject.request(path: "/test", api_version: 1)
        end

        it "should not modify path if base path is detected" do
          expect(connection).to receive(:request).with(hash_including(path: "#{base_path}/custom/request"))
          subject.request(path: "/custom/path/custom/request")
        end
      end
    end

    context "when response body is valid json" do
      let(:body) { {result: true}.to_json }

      it "should parse the return the JSON value" do
        expect(subject.request(path: "/")).to eq({result: true})
      end
    end

    context "with parameters" do
      [:get, :head, :delete].each do |request_method|
        it "should use query parameters for #{request_method.to_s.upcase} request method" do
          expect(connection).to receive(:request).with(hash_including(query: anything)).
            and_return(response)
          subject.request(path: "/", method: request_method, params: {testing: true})
        end
      end

      it "should use JSON body parameters for other request methods" do
        expect(connection).to receive(:request).with(hash_including(body: anything)).
          and_return(response)
        subject.request(path: "/", method: :post, params: {testing: true})
      end

      it "should pass parameter hash through in request" do
        expect(connection).to receive(:request).with(hash_including(query: {testing: true})).
          and_return(response)
        subject.request(path: "/", params: {testing: true})
      end

      it "should remove parameters that were not explicitly set" do
        expect(connection).to receive(:request).with(hash_including(query: {testing: true})).
          and_return(response)
        subject.request(path: "/", params: {testing: true, invalid: VagrantCloud::Data::Nil})
      end
    end

    context "idempotent information" do
      [:get, :head].each do |request_method|
        it "should set idempotent options for #{request_method.to_s.upcase} request method" do
          expect(connection).to receive(:request).
            with(hash_including(idempotent: anything, retry_limit: anything, retry_interval: anything)).
            and_return(response)
          subject.request(path: "/", method: request_method)
        end
      end

      it "should not set idempotent options for other request methods" do
        expect(connection).to receive(:request) do |args|
          expect(args.keys).not_to include(:idempotent)
          expect(args.keys).not_to include(:retry_limit)
          expect(args.keys).not_to include(:retry_interval)
          response
        end
        subject.request(path: "/", method: :post)
      end
    end

    context "with errors" do
      context "with request errors" do
        let(:response) { double("response", status: 403, body: '{"errors": ["forbidden request"]}') }

        before { expect(connection).to receive(:request).and_raise(Excon::Error::Forbidden.new("forbidden", nil, response)) }

        it "should raise a wrapped error" do
          expect { subject.request(path: "/") }.to raise_error(VagrantCloud::Error::ClientError::RequestError)
        end

        it "should set the error message from the content" do
          err = nil
          subject.request(path: "/")
        rescue => err
          expect(err.error_arr).to eq(["forbidden request"])
        end

        it "should set the error status code" do
          err = nil
          subject.request(path: "/")
        rescue => err
          expect(err.error_code).to eq(403)
        end
      end
    end
  end

  describe "#clone" do
    it "should create a new clone" do
      expect(subject.clone).to be_a(described_class)
    end

    it "should be a new instance" do
      expect(subject.clone).not_to be(subject)
    end

    it "should clone custom settings" do
      subject = described_class.new(url_base: "http://example.com")
      expect(subject.clone.url_base).to eq("http://example.com")
    end

    it "should override the access_token when provided" do
      subject = described_class.new(access_token: "token")
      expect(subject.clone(access_token: "new-token").access_token).to eq("new-token")
    end
  end

  describe "#authentication_token_create" do
    let(:username) { double("username") }
    let(:password) { double("password") }
    let(:description) { double("description") }
    let(:code) { double("code") }

    it "should require a username" do
      expect { subject.authentication_token_create(password: password) }.
        to raise_error(ArgumentError)
    end

    it "should require a password" do
      expect { subject.authentication_token_create(username: username) }.
        to raise_error(ArgumentError)
    end

    it "should send remote request and include username and password" do
      expect(subject).to receive(:request) do |args|
        expect(args[:path]).to include("authenticate")
        expect(args[:method]).to eq(:post)
        expect(args.dig(:params, :user, :login)).to eq(username)
        expect(args.dig(:params, :user, :password)).to eq(password)
      end
      subject.authentication_token_create(username: username, password: password)
    end

    it "should include description and code if provided" do
      expect(subject).to receive(:request) do |args|
        expect(args.dig(:params, :token, :description)).to eq(description)
        expect(args.dig(:params, :two_factor, :code)).to eq(code)
      end
      subject.authentication_token_create(username: username, password: password,
        description: description, code: code)
    end

    it "should use v1 API" do
      expect(subject).to receive(:request) do |args|
        expect(args[:api_version]).to eq(1)
      end

      subject.authentication_token_create(username: username, password: password)
    end
  end

  describe "#authentication_token_delete" do
    it "should send delete request" do
      expect(subject).to receive(:request).with(hash_including(method: :delete, path: "authenticate"))
      subject.authentication_token_delete
    end

    it "should use v1 API" do
      expect(subject).to receive(:request) do |args|
        expect(args[:api_version]).to eq(1)
      end
      subject.authentication_token_delete
    end
  end

  describe "#authentication_request_2fa_code" do
    let(:username) { double("username") }
    let(:password) { double("password") }
    let(:delivery_method) { method("delivery_method") }
    let(:args) { {username: username, password: password, delivery_method: delivery_method} }

    it "should require a username" do
      args.delete(:username)
      expect { subject.authentication_request_2fa_code(**args) }.
        to raise_error(ArgumentError)
    end

    it "should require a password" do
      args.delete(:password)
      expect { subject.authentication_request_2fa_code(**args) }.
        to raise_error(ArgumentError)
    end

    it "should require a delivery method" do
      args.delete(:delivery_method)
      expect { subject.authentication_request_2fa_code(**args) }.
        to raise_error(ArgumentError)
    end

    it "should include username, password, and delivery method in request" do
      expect(subject).to receive(:request) do |args|
        expect(args.dig(:params, :two_factor, :delivery_method)).to eq(delivery_method)
        expect(args.dig(:params, :user, :login)).to eq(username)
        expect(args.dig(:params, :user, :password)).to eq(password)
      end
      subject.authentication_request_2fa_code(**args)
    end

    it "should post to the two factor request path" do
      expect(subject).to receive(:request).with(hash_including(method: :post, path: "two-factor/request-code"))
      subject.authentication_request_2fa_code(**args)
    end

    it "should use v1 API" do
      expect(subject).to receive(:request) do |args|
        expect(args[:api_version]).to eq(1)
      end
      subject.authentication_request_2fa_code(**args)
    end
  end

  describe "#search" do
    let(:query) { double("query") }
    let(:provider) { double("provider") }
    let(:sort) { double("sort") }
    let(:order) { "asc" }
    let(:limit) { 53 }
    let(:page) { 101 }
    let(:args) { {query: query, provider: provider, sort: sort, order: order, limit: limit, page: page} }

    it "should sent request for search" do
      expect(subject).to receive(:request).with(hash_including(method: :get, path: "search"))
      subject.search(**args)
    end

    it "should include given values within request parameters" do
      expect(subject).to receive(:request) do |args|
        expect(args.dig(:params, :q)).to eq(query)
        expect(args.dig(:params, :provider)).to eq(provider)
        expect(args.dig(:params, :sort)).to eq(sort)
        expect(args.dig(:params, :order)).to eq(order)
        expect(args.dig(:params, :limit)).to eq(limit)
        expect(args.dig(:params, :page)).to eq(page)
      end
      subject.search(**args)
    end
  end


  describe "#box_get" do
    before { allow(subject).to receive(:request) }

    it "should require username is provided" do
      expect { subject.box_get(name: "mybox") }.to raise_error(ArgumentError)
    end

    it "should require name is provided" do
      expect { subject.box_get(username: "myname") }.to raise_error(ArgumentError)
    end

    it "should send the remote request with username and name" do
      expect(subject).to receive(:request) do |args|
        expect(args[:path]).to include("myname")
        expect(args[:path]).to include("mybox")
      end
      subject.box_get(username: "myname", name: "mybox")
    end
  end

  describe "#box_create" do
    let(:name) { double("name") }
    let(:username) { double("username") }
    let(:description) { double("description") }
    let(:short_description) { double("short_description") }
    let(:is_private) { double("is_private") }

    before { allow(subject).to receive(:request) }

    it "should require username is provided" do
      expect { subject.box_create(name: name) }.to raise_error(ArgumentError)
    end

    it "should require name is provided" do
      expect { subject.box_create(username: username) }.to raise_error(ArgumentError)
    end

    it "should only require username and name" do
      expect(subject).to receive(:request)
      subject.box_create(username: username, name: name)
    end

    it "should include description" do
      expect(subject).to receive(:request) do |args|
        expect(args.dig(:params, :box, :description)).to eq(description)
      end
      subject.box_create(username: username, name: name, description: description)
    end

    it "should include short_description" do
      expect(subject).to receive(:request) do |args|
        expect(args.dig(:params, :box, :short_description)).to eq(short_description)
      end
      subject.box_create(username: username, name: name, short_description: short_description)
    end

    it "should include is_private" do
      expect(subject).to receive(:request) do |args|
        expect(args.dig(:params, :box, :is_private)).to eq(is_private)
      end
      subject.box_create(username: username, name: name, is_private: is_private)
    end
  end

  describe "#box_update" do
    let(:username) { double("username") }
    let(:name) { double("name") }
    let(:short_description) { double("short_description") }
    let(:description) { double("description") }
    let(:is_private) { double("is_private") }

    before { allow(subject).to receive(:request) }

    it "should require username is provided" do
      expect { subject.box_update(name: name) }.to raise_error(ArgumentError)
    end

    it "should require name is provided" do
      expect { subject.box_update(username: username) }.to raise_error(ArgumentError)
    end

    it "should only require username and name" do
      expect(subject).to receive(:request)
      subject.box_update(username: username, name: name)
    end

    it "should include description" do
      expect(subject).to receive(:request) do |args|
        expect(args.dig(:params, :box, :description)).to eq(description)
      end
      subject.box_update(username: username, name: name, description: description)
    end

    it "should include short_description" do
      expect(subject).to receive(:request) do |args|
        expect(args.dig(:params, :box, :short_description)).to eq(short_description)
      end
      subject.box_update(username: username, name: name, short_description: short_description)
    end

    it "should include is_private" do
      expect(subject).to receive(:request) do |args|
        expect(args.dig(:params, :box, :is_private)).to eq(is_private)
      end
      subject.box_update(username: username, name: name, is_private: is_private)
    end
  end

  describe "#box_delete" do
    let(:username) { double("username") }
    let(:name) { double("name") }

    before { allow(subject).to receive(:request) }

    it "should require username is provided" do
      expect { subject.box_delete(name: name) }.to raise_error(ArgumentError)
    end

    it "should require name is provided" do
      expect { subject.box_delete(username: username) }.to raise_error(ArgumentError)
    end

    it "should send deletion request" do
      expect(subject).to receive(:request)
      subject.box_delete(username: username, name: name)
    end
  end

  describe "#box_version_get" do
    let(:username) { double("username") }
    let(:name) { double("name") }
    let(:version) { double("version") }

    before { allow(subject).to receive(:request) }

    it "should require username is provided" do
      expect { subject.box_version_get(name: name, version: version) }.
        to raise_error(ArgumentError)
    end

    it "should require name is provided" do
      expect { subject.box_version_get(username: username, version: version) }.
        to raise_error(ArgumentError)
    end

    it "should require version is provided" do
      expect { subject.box_version_get(username: username, name: name) }.
        to raise_error(ArgumentError)
    end

    it "should request the box version" do
      expect(subject).to receive(:request)
      subject.box_version_get(username: username, name: name, version: version)
    end
  end

  describe "#box_version_create" do
    let(:username) { double("username") }
    let(:name) { double("name") }
    let(:version) { double("version") }
    let(:description) { double("description") }

    before { allow(subject).to receive(:request) }

    it "should require username is provided" do
      expect { subject.box_version_create(name: name, version: version) }.
        to raise_error(ArgumentError)
    end

    it "should require name is provided" do
      expect { subject.box_version_create(username: username, version: version) }.
        to raise_error(ArgumentError)
    end

    it "should require version is provided" do
      expect { subject.box_version_create(username: username, name: name) }.
        to raise_error(ArgumentError)
    end

    it "should request the version creation" do
      expect(subject).to receive(:request)
      subject.box_version_create(username: username, name: name, version: version)
    end

    it "should make request using POST method" do
      expect(subject).to receive(:request).with(hash_including(method: :post))
      subject.box_version_create(username: username, name: name, version: version)
    end

    it "should include description if provided" do
      expect(subject).to receive(:request) do |args|
        expect(args.dig(:params, :version, :description)).to eq(description)
      end
      subject.box_version_create(username: username, name: name, version: version, description: description)
    end

    it "should include the version in the parameters" do
      expect(subject).to receive(:request) do |args|
        expect(args.dig(:params, :version, :version)).to eq(version)
      end
      subject.box_version_create(username: username, name: name, version: version)
    end
  end

  describe "#box_version_update" do
    let(:username) { double("username") }
    let(:name) { double("name") }
    let(:version) { double("version") }
    let(:description) { double("description") }

    before { allow(subject).to receive(:request) }

    it "should require username is provided" do
      expect { subject.box_version_update(name: name, version: version) }.
        to raise_error(ArgumentError)
    end

    it "should require name is provided" do
      expect { subject.box_version_update(username: username, version: version) }.
        to raise_error(ArgumentError)
    end

    it "should require version is provided" do
      expect { subject.box_version_update(username: username, name: name) }.
        to raise_error(ArgumentError)
    end

    it "should request the version update" do
      expect(subject).to receive(:request)
      subject.box_version_update(username: username, name: name, version: version)
    end

    it "should make request using PUT method" do
      expect(subject).to receive(:request).with(hash_including(method: :put))
      subject.box_version_update(username: username, name: name, version: version)
    end

    it "should include description if provided" do
      expect(subject).to receive(:request) do |args|
        expect(args.dig(:params, :version, :description)).to eq(description)
      end
      subject.box_version_update(username: username, name: name, version: version, description: description)
    end

    it "should include the version in the parameters" do
      expect(subject).to receive(:request) do |args|
        expect(args.dig(:params, :version, :version)).to eq(version)
      end
      subject.box_version_update(username: username, name: name, version: version)
    end
  end

  describe "#box_version_delete" do
    let(:username) { double("username") }
    let(:name) { double("name") }
    let(:version) { double("version") }

    before { allow(subject).to receive(:request) }

    it "should require username is provided" do
      expect { subject.box_version_delete(name: name, version: version) }.
        to raise_error(ArgumentError)
    end

    it "should require name is provided" do
      expect { subject.box_version_delete(username: username, version: version) }.
        to raise_error(ArgumentError)
    end

    it "should require version is provided" do
      expect { subject.box_version_delete(username: username, name: name) }.
        to raise_error(ArgumentError)
    end

    it "should request the version delete" do
      expect(subject).to receive(:request)
      subject.box_version_delete(username: username, name: name, version: version)
    end

    it "should make request using DELETE method" do
      expect(subject).to receive(:request).with(hash_including(method: :delete))
      subject.box_version_delete(username: username, name: name, version: version)
    end
  end

  describe "#box_version_release" do
    let(:username) { double("username") }
    let(:name) { double("name") }
    let(:version) { double("version") }

    before { allow(subject).to receive(:request) }

    it "should require username is provided" do
      expect { subject.box_version_release(name: name, version: version) }.
        to raise_error(ArgumentError)
    end

    it "should require name is provided" do
      expect { subject.box_version_release(username: username, version: version) }.
        to raise_error(ArgumentError)
    end

    it "should require version is provided" do
      expect { subject.box_version_release(username: username, name: name) }.
        to raise_error(ArgumentError)
    end

    it "should request the version release" do
      expect(subject).to receive(:request) do |args|
        expect(args[:path]).to include("release")
      end
      subject.box_version_release(username: username, name: name, version: version)
    end

    it "should make request using PUT method" do
      expect(subject).to receive(:request).with(hash_including(method: :put))
      subject.box_version_release(username: username, name: name, version: version)
    end
  end

  describe "#box_version_revoke" do
    let(:username) { double("username") }
    let(:name) { double("name") }
    let(:version) { double("version") }

    before { allow(subject).to receive(:request) }

    it "should require username is provided" do
      expect { subject.box_version_revoke(name: name, version: version) }.
        to raise_error(ArgumentError)
    end

    it "should require name is provided" do
      expect { subject.box_version_revoke(username: username, version: version) }.
        to raise_error(ArgumentError)
    end

    it "should require version is provided" do
      expect { subject.box_version_revoke(username: username, name: name) }.
        to raise_error(ArgumentError)
    end

    it "should request the version revoke" do
      expect(subject).to receive(:request) do |args|
        expect(args[:path]).to include("revoke")
      end
      subject.box_version_revoke(username: username, name: name, version: version)
    end

    it "should make request using PUT method" do
      expect(subject).to receive(:request).with(hash_including(method: :put))
      subject.box_version_revoke(username: username, name: name, version: version)
    end
  end

  describe "#box_version_provider_get" do
    let(:username) { double("username") }
    let(:name) { double("name") }
    let(:version) { double("version") }
    let(:provider) { double("provider") }
    let(:architecture) { "TEST_ARCHITECTURE" }

    before { allow(subject).to receive(:request) }

    it "should require username is provided" do
      expect { subject.box_version_provider_get(name: name, version: version, provider: provider) }.
        to raise_error(ArgumentError)
    end

    it "should require name is provided" do
      expect { subject.box_version_provider_get(username: username, version: version, provider: provider) }.
        to raise_error(ArgumentError)
    end

    it "should require version is provided" do
      expect { subject.box_version_provider_get(username: username, name: name, provider: provider) }.
        to raise_error(ArgumentError)
    end

    it "should require provider is provided" do
      expect { subject.box_version_provider_get(username: username, name: name, version: version) }.
        to raise_error(ArgumentError)
    end

    it "should include architecture when provided" do
      expect(subject).to receive(:request) do |args|
        expect(args[:path]).to include(architecture)
      end

      subject.box_version_provider_get(
        username: username,
        name: name,
        version: version,
        provider: provider,
        architecture: architecture
      )
    end

    it "should request the box version provider" do
      expect(subject).to receive(:request)

      subject.box_version_provider_get(
        username: username,
        name: name,
        version: version,
        provider: provider
      )
    end
  end

  describe "#box_version_provider_create" do
    let(:username) { double("username") }
    let(:name) { double("name") }
    let(:version) { double("version") }
    let(:provider) { double("provider") }
    let(:url) { double("url") }
    let(:checksum) { double("checksum") }
    let(:checksum_type) { double("checksum_type") }
    let(:architecture) { double("architecture") }
    let(:default_architecture) { double("default_architecture") }

    before { allow(subject).to receive(:request) }

    it "should require username is provided" do
      expect {
        subject.box_version_provider_create(
          name: name,
          version: version,
          provider: provider)
      }.to raise_error(ArgumentError)
    end

    it "should require name is provided" do
      expect {
        subject.box_version_provider_create(
          username: username,
          version: version,
          provider: provider)
      }.to raise_error(ArgumentError)
    end

    it "should require version is provided" do
      expect {
        subject.box_version_provider_create(
          username: username,
          name: name,
          provider: provider)
      }.to raise_error(ArgumentError)
    end

    it "should require provider is provided" do
      expect {
        subject.box_version_provider_create(
          username: username,
          name: name,
          version: version
        )
      }.to raise_error(ArgumentError)
    end

    it "should create the box version provider" do
      expect(subject).to receive(:request)

      subject.box_version_provider_create(
        username: username,
        name: name,
        version: version,
        provider: provider
      )
    end

    it "should create the box version provider with POST method" do
      expect(subject).to receive(:request).with(hash_including(method: :post))

      subject.box_version_provider_create(
        username: username,
        name: name,
        version: version,
        provider: provider
      )
    end

    it "should include url if provided" do
      expect(subject).to receive(:request) do |args|
        expect(args.dig(:params, :provider, :url)).to eq(url)
      end

      subject.box_version_provider_create(
        username: username,
        name: name,
        version: version,
        provider: provider,
        url: url
      )
    end

    it "should include checksum if provided" do
      expect(subject).to receive(:request) do |args|
        expect(args.dig(:params, :provider, :checksum)).to eq(checksum)
      end

      subject.box_version_provider_create(
        username: username,
        name: name,
        version: version,
        provider: provider,
        checksum: checksum
      )
    end

    it "should include checksum_type if provided" do
      expect(subject).to receive(:request) do |args|
        expect(args.dig(:params, :provider, :checksum_type)).to eq(checksum_type)
      end

      subject.box_version_provider_create(
        username: username,
        name: name,
        version: version,
        provider: provider,
        checksum_type: checksum_type
      )
    end

    context "architecture" do
      context "when not included" do
        after do
          subject.box_version_provider_create(
            username: username,
            name: name,
            version: version,
            provider: provider,
            checksum_type: checksum_type
          )
        end

        it "should not be in params" do
          expect(subject).to receive(:request) do |args|
            expect(args.dig(:params, :provider).key?(:architecture)).to be_falsey
          end
        end

        it "should call the v1 API" do
          expect(subject).to receive(:request) do |args|
            expect(args[:api_version]).to eq(1)
          end
        end
      end

      context "when included" do
        after do
          subject.box_version_provider_create(
            username: username,
            name: name,
            version: version,
            provider: provider,
            checksum_type: checksum_type,
            architecture: architecture
          )
        end

        it "should be in params" do
          expect(subject).to receive(:request) do |args|
            expect(args.dig(:params, :provider, :architecture)).to eq(architecture)
          end
        end

        it "should call the v2 API" do
          expect(subject).to receive(:request) do |args|
            expect(args[:api_version]).to eq(2)
          end
        end
      end
    end

    context "default architecture" do
      it "should be default nil value when not provided" do
        expect(subject).to receive(:request) do |args|
          expect(args.dig(:params, :provider, :default_architecture)).to eq(VagrantCloud::Data::Nil)
        end

        subject.box_version_provider_create(
          username: username,
          name: name,
          version: version,
          provider: provider,
          architecture: architecture,
          checksum_type: checksum_type
        )
      end

      context "when value is true" do
        it "should include default architecture as true" do
          expect(subject).to receive(:request) do |args|
            expect(args.dig(:params, :provider, :default_architecture)).to be_truthy
          end

          subject.box_version_provider_create(
            username: username,
            name: name,
            version: version,
            provider: provider,
            checksum_type: checksum_type,
            architecture: architecture,
            default_architecture: true
          )
        end
      end

      context "when value is false" do
        it "should include default architecture as false" do
          expect(subject).to receive(:request) do |args|
            expect(args.dig(:params, :provider, :default_architecture)).to be(false)
          end

          subject.box_version_provider_create(
            username: username,
            name: name,
            version: version,
            provider: provider,
            checksum_type: checksum_type,
            architecture: architecture,
            default_architecture: false
          )
        end
      end

      context "when architecture is not provided" do
        it "should not be included" do
          expect(subject).to receive(:request) do |args|
            expect(args.dig(:params, :provider).key?(:default_architecture)).to be_falsey
          end

          subject.box_version_provider_create(
            username: username,
            name: name,
            version: version,
            provider: provider,
            checksum_type: checksum_type,
            default_architecture: false
          )
        end
      end
    end
  end

  describe "#box_version_provider_update" do
    let(:username) { double("username") }
    let(:name) { double("name") }
    let(:version) { double("version") }
    let(:provider) { double("provider") }
    let(:url) { double("url") }
    let(:checksum) { double("checksum") }
    let(:checksum_type) { double("checksum_type") }
    let(:architecture) { "TEST_ARCHITECTURE" }
    let(:new_architecture) { double("new_architecture") }

    before { allow(subject).to receive(:request) }

    it "should require username is provided" do
      expect {
        subject.box_version_provider_update(
          name: name,
          version: version,
          provider: provider
        )
      }.to raise_error(ArgumentError)
    end

    it "should require name is provided" do
      expect {
        subject.box_version_provider_update(
          username: username,
          version: version,
          provider: provider)
      }.to raise_error(ArgumentError)
    end

    it "should require version is provided" do
      expect {
        subject.box_version_provider_update(
          username: username,
          name: name,
          provider: provider
        )
      }.to raise_error(ArgumentError)
    end

    it "should require provider is provided" do
      expect {
        subject.box_version_provider_update(
          username: username,
          name: name,
          version: version
        )
      }.to raise_error(ArgumentError)
    end

    it "should update the box version provider" do
      expect(subject).to receive(:request)

      subject.box_version_provider_update(
        username: username,
        name: name,
        version: version,
        provider: provider
      )
    end

    it "should update the box version provider with PUT method" do
      expect(subject).to receive(:request).with(hash_including(method: :put))

      subject.box_version_provider_update(
        username: username,
        name: name,
        version: version,
        provider: provider
      )
    end

    it "should include url if provided" do
      expect(subject).to receive(:request) do |args|
        expect(args.dig(:params, :provider, :url)).to eq(url)
      end

      subject.box_version_provider_update(
        username: username,
        name: name,
        version: version,
        provider: provider,
        url: url
      )
    end

    it "should include checksum if provided" do
      expect(subject).to receive(:request) do |args|
        expect(args.dig(:params, :provider, :checksum)).to eq(checksum)
      end

      subject.box_version_provider_update(
        username: username,
        name: name,
        version: version,
        provider: provider,
        checksum: checksum
      )
    end

    it "should include checksum_type if provided" do
      expect(subject).to receive(:request) do |args|
        expect(args.dig(:params, :provider, :checksum_type)).to eq(checksum_type)
      end

      subject.box_version_provider_update(
        username: username,
        name: name,
        version: version,
        provider: provider,
        checksum_type: checksum_type
      )
    end

    context "architecture" do
      context "when provided" do
        after do
          subject.box_version_provider_update(
            username: username,
            name: name,
            version: version,
            provider: provider,
            architecture: architecture,
            checksum_type: checksum_type
          )
        end

        it "should be included in the path" do
          expect(subject).to receive(:request) do |args|
            expect(args[:path]).to include(architecture)
          end
        end

        it "should use v2 API" do
          expect(subject).to receive(:request) do |args|
            expect(args[:api_version]).to eq(2)
          end
        end
      end

      context "when not provided" do
        after do
          subject.box_version_provider_update(
            username: username,
            name: name,
            version: version,
            provider: provider,
            checksum_type: checksum_type
          )
        end

        it "should use v1 API" do
          expect(subject).to receive(:request) do |args|
            expect(args[:api_version]).to eq(1)
          end
        end
      end
    end

    context "new architecture" do
      context "when architecture is provided" do
        it "should be default nil value when not provided" do
          expect(subject).to receive(:request) do |args|
            expect(args.dig(:params, :provider, :architecture)).to eq(VagrantCloud::Data::Nil)
          end

          subject.box_version_provider_update(
            username: username,
            name: name,
            version: version,
            provider: provider,
            checksum_type: checksum_type,
            architecture: architecture
          )
        end

        it "should be included when provided" do
          expect(subject).to receive(:request) do |args|
            expect(args.dig(:params, :provider, :architecture)).to eq(new_architecture)
          end

          subject.box_version_provider_update(
            username: username,
            name: name,
            version: version,
            provider: provider,
            checksum_type: checksum_type,
            architecture: architecture,
            new_architecture: new_architecture
          )
        end
      end

      context "when architecture is not provided" do
        it "should not be included in params" do
          expect(subject).to receive(:request) do |args|
            expect(args.dig(:params, :provider).key?(:new_architecture)).to be(false)
          end

          subject.box_version_provider_update(
            username: username,
            name: name,
            version: version,
            provider: provider,
            checksum_type: checksum_type,
            new_architecture: new_architecture
          )
        end
      end
    end

    context "default architecture" do
      context "when architecture is provided" do
        it "should be default nil value when not provided" do
          expect(subject).to receive(:request) do |args|
            expect(args.dig(:params, :provider, :default_architecture)).to eq(VagrantCloud::Data::Nil)

          end
          subject.box_version_provider_update(
            username: username,
            name: name,
            version: version,
            provider: provider,
            checksum_type: checksum_type,
            architecture: architecture,
          )
        end

        context "when value is true" do
          it "should include default architecture as true" do
            expect(subject).to receive(:request) do |args|
              expect(args.dig(:params, :provider, :default_architecture)).to be_truthy
            end

            subject.box_version_provider_update(
              username: username,
              name: name,
              version: version,
              provider: provider,
              checksum_type: checksum_type,
              architecture: architecture,
              default_architecture: true
            )
          end
        end

        context "when value is false" do
          it "should include default architecture as false" do
            expect(subject).to receive(:request) do |args|
              expect(args.dig(:params, :provider, :default_architecture)).to be(false)
            end

            subject.box_version_provider_update(
              username: username,
              name: name,
              version: version,
              provider: provider,
              checksum_type: checksum_type,
              architecture: architecture,
              default_architecture: false
            )
          end
        end
      end

      context "when architecture is not provided" do
        it "should not be included in params" do
          expect(subject).to receive(:request) do |args|
            expect(args.dig(:params, :provider).key?(:default_architecture)).to be(false)
          end

          subject.box_version_provider_update(
            username: username,
            name: name,
            version: version,
            provider: provider,
            checksum_type: checksum_type,
            default_architecture: true
          )
        end
      end
    end
  end

  describe "#box_version_provider_delete" do
    let(:username) { double("username") }
    let(:name) { double("name") }
    let(:version) { double("version") }
    let(:provider) { double("provider") }
    let(:architecture) { "TEST_ARCHITECTURE" }

    before { allow(subject).to receive(:request) }

    it "should require username is provided" do
      expect {
        subject.box_version_provider_delete(
          name: name,
          version: version,
          provider: provider)
      }.to raise_error(ArgumentError)
    end

    it "should require name is provided" do
      expect {
        subject.box_version_provider_delete(
          username: username,
          version: version,
          provider: provider)
      }.to raise_error(ArgumentError)
    end

    it "should require version is provided" do
      expect {
        subject.box_version_provider_delete(
          username: username,
          name: name,
          provider: provider
        )
      }.to raise_error(ArgumentError)
    end

    it "should require provider is provided" do
      expect {
        subject.box_version_provider_delete(
          username: username,
          name: name,
          version: version)
      }.to raise_error(ArgumentError)
    end

    it "should delete the box version provider" do
      expect(subject).to receive(:request)

      subject.box_version_provider_delete(
        username: username,
        name: name,
        version: version,
        provider: provider
      )
    end

    it "should delete the box version provider with DELETE method" do
      expect(subject).to receive(:request).with(hash_including(method: :delete))

      subject.box_version_provider_delete(
        username: username,
        name: name,
        version: version,
        provider: provider
      )
    end

    context "with architecture" do
      after do
        subject.box_version_provider_delete(
          username: username,
          name: name,
          version: version,
          provider: provider,
          architecture: architecture
        )
      end

      it "should include architecture when provided" do
        expect(subject).to receive(:request) do |args|
          expect(args[:path]).to include(architecture)
        end
      end

      it "should use v2 API" do
        expect(subject).to receive(:request) do |args|
          expect(args[:api_version]).to eq(2)
        end
      end
    end

    context "without architecture" do
      it "should use v1 API" do
        expect(subject).to receive(:request) do |args|
          expect(args[:api_version]).to eq(1)
        end

        subject.box_version_provider_delete(
          username: username,
          name: name,
          version: version,
          provider: provider,
        )
      end
    end
  end

  describe "#box_version_provider_upload" do
    let(:username) { double("username") }
    let(:name) { double("name") }
    let(:version) { double("version") }
    let(:provider) { double("provider") }
    let(:architecture) { "TEST_ARCHITECTURE" }

    before { allow(subject).to receive(:request) }

    it "should require username is provided" do
      expect {
        subject.box_version_provider_upload(
          name: name,
          version: version,
          provider: provider
        )
      }.to raise_error(ArgumentError)
    end

    it "should require name is provided" do
      expect {
        subject.box_version_provider_upload(
          username: username,
          version: version,
          provider: provider
        )
      }.to raise_error(ArgumentError)
    end

    it "should require version is provided" do
      expect {
        subject.box_version_provider_upload(
          username: username,
          name: name,
          provider: provider
        )
      }.to raise_error(ArgumentError)
    end

    it "should require provider is provided" do
      expect {
        subject.box_version_provider_upload(
          username: username,
          name: name,
          version: version
        )
      }.to raise_error(ArgumentError)
    end

    it "should send upload request for the box version provider" do
      expect(subject).to receive(:request)

      subject.box_version_provider_upload(
        username: username,
        name: name,
        version: version,
        provider: provider
      )
    end

    it "should request the box version provider upload with GET method" do
      expect(subject).to receive(:request).with(hash_including(method: :get))

      subject.box_version_provider_upload(
        username: username,
        name: name,
        version: version,
        provider: provider
      )
    end

    context "with architecture" do
      after do
        subject.box_version_provider_upload(
          username: username,
          name: name,
          version: version,
          provider: provider,
          architecture: architecture
        )
      end

      it "should include architecture when provided" do
        expect(subject).to receive(:request) do |args|
          expect(args[:path]).to include(architecture)
        end
      end

      it "should use v2 API" do
        expect(subject).to receive(:request) do |args|
          expect(args[:api_version]).to eq(2)
        end
      end
    end

    context "without architecture" do
      it "should use v1 API" do
        expect(subject).to receive(:request) do |args|
          expect(args[:api_version]).to eq(1)
        end

        subject.box_version_provider_upload(
          username: username,
          name: name,
          version: version,
          provider: provider
        )
      end
    end

    it "should request the upload path" do
      expect(subject).to receive(:request) do |args|
        expect(args[:path]).to include("upload")
      end

      subject.box_version_provider_upload(
        username: username,
        name: name,
        version: version,
        provider: provider
      )
    end
  end

  describe "#box_version_provider_upload_direct" do
    let(:username) { double("username") }
    let(:name) { double("name") }
    let(:version) { double("version") }
    let(:provider) { double("provider") }
    let(:architecture) { "TEST_ARCHITECTURE" }

    before { allow(subject).to receive(:request) }

    it "should require username is provided" do
      expect {
        subject.box_version_provider_upload_direct(
          name: name,
          version: version,
          provider: provider
        )
      }.to raise_error(ArgumentError)
    end

    it "should require name is provided" do
      expect {
        subject.box_version_provider_upload_direct(
          username: username,
          version: version,
          provider: provider
        )
      }.to raise_error(ArgumentError)
    end

    it "should require version is provided" do
      expect {
        subject.box_version_provider_upload_direct(
          username: username,
          name: name,
          provider: provider
        )
      }.to raise_error(ArgumentError)
    end

    it "should require provider is provided" do
      expect {
        subject.box_version_provider_upload_direct(
          username: username,
          name: name,
          version: version
        )
      }.to raise_error(ArgumentError)
    end

    it "should send upload request for the box version provider" do
      expect(subject).to receive(:request)

      subject.box_version_provider_upload_direct(
        username: username,
        name: name,
        version: version,
        provider: provider
      )
    end

    it "should request the box version provider upload with GET method" do
      expect(subject).to receive(:request).with(hash_including(method: :get))

      subject.box_version_provider_upload_direct(
        username: username,
        name: name,
        version: version,
        provider: provider
      )
    end

    it "should request the upload path" do
      expect(subject).to receive(:request) do |args|
        expect(args[:path]).to include("upload")
      end

      subject.box_version_provider_upload_direct(
        username: username,
        name: name,
        version: version,
        provider: provider
      )
    end

    context "with architecture" do
      after do
        subject.box_version_provider_upload_direct(
          username: username,
          name: name,
          version: version,
          provider: provider,
          architecture: architecture
        )

        it "should be included in path" do
          expect(subject).to receive(:request) do |args|
            expect(args[:path]).to include(architecture)
          end
        end

        it "should use v2 API" do
          expect(subject).to receive(:request) do |args|
            expect(args[:api_version]).to eq(2)
          end
        end
      end
    end

    context "without architecture" do
      it "should use v1 API" do
        expect(subject).to receive(:request) do |args|
          expect(args[:api_version]).to eq(1)
        end

        subject.box_version_provider_upload_direct(
          username: username,
          name: name,
          version: version,
          provider: provider,
        )
      end
    end
  end
end
