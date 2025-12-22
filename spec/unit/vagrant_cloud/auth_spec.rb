# Copyright IBM Corp. 2014, 2025
# SPDX-License-Identifier: MIT

require 'spec_helper'
require 'vagrant_cloud'

describe VagrantCloud::Auth do
  let(:client_id) { nil }
  let(:client_secret) { nil }
  let(:auth_url) { nil }
  let(:auth_path) { nil }
  let(:token_path) { nil }

  # Remove any environment variables that
  # maybe set that are used by auth
  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("HCP_CLIENT_ID").and_return(client_id)
    allow(ENV).to receive(:[]).with("HCP_CLIENT_SECRET").and_return(client_secret)
    allow(ENV).to receive(:fetch) do |name, default_value|
      send(name.sub("HCP_", "").downcase) || default_value
    end
  end

  describe "#initialize" do
    context "with no arguments" do
      describe "#token" do
        it "should return nil" do
          expect(subject.token).to be_nil
        end
      end

      describe "#available?" do
        it "should return false" do
          expect(subject).not_to be_available
        end
      end
    end

    context "with access token provided" do
      let(:token) { "test-access-token" }
      subject { described_class.new(access_token: token) }

      describe "#token" do
        it "should return the access token" do
          expect(subject.token).to eq(token)
        end
      end

      describe "#available?" do
        it "should return true" do
          expect(subject).to be_available
        end
      end
    end

    context "with HCP_CLIENT_ID only set" do
      let(:client_id) { "test-client-id" }

      describe "#initialize" do
        it "should raise an argument error" do
          expect { subject }.to raise_error(ArgumentError)
        end
      end
    end

    context "with HCP_CLIENT_SECRET only set" do
      let(:client_secret) { "test-client-secret" }

      describe "#initialize" do
        it "should raise an argument error" do
          expect { subject }.to raise_error(ArgumentError)
        end
      end
    end

    context "with HCP_CLIENT_ID and HCP_CLIENT_SECRET set" do
      let(:client_secret) { "test-client-secret" }
      let(:client_id) { "test-client-id" }

      let(:token) { "test-access-token" }
      let(:expires_at) { Time.now.to_i + 10 }
      let(:token_response) { double(:token_response, token: token, expires_at: expires_at) }
      let(:client) { double(:client, client_credentials: client_credentials) }
      let(:client_credentials) { double(:client_credentials, get_token: token_response) }

      let(:retry_token) { "retry-test-access-token" }
      let(:retry_expires_at) { Time.now.to_i + 10 }
      let(:retry_token_response) { double(:token_response, token: retry_token, expires_at: retry_expires_at) }
      let(:retry_client_credentials) { double(:client_credentials, get_token: retry_token_response) }


      before do
        allow(OAuth2::Client).to receive(:new).and_return(client)
      end

      describe "#token" do
        it "should return the access token" do
          expect(subject.token).to eq(token)
        end

        context "with expired token" do
          let(:expires_at) { Time.now.to_i - 5 }

          before do
            expect(client).to receive(:client_credentials).and_return(client_credentials)
            expect(client).to receive(:client_credentials).and_return(retry_client_credentials)
          end

          it "should return the updated access token" do
            subject.token # to seed the internal value
            expect(subject.token).to eq(retry_token)
          end
        end

        it "should properly configure the oauth2 client" do
          expect(OAuth2::Client).to receive(:new).with(client_id, client_secret, hash_including(
            site: described_class.const_get(:DEFAULT_AUTH_URL),
            authorize_url: described_class.const_get(:DEFAULT_AUTH_PATH),
            token_url: described_class.const_get(:DEFAULT_TOKEN_PATH),
          )).and_return(client)

          expect(subject.token).to eq(token)
        end

        context "with HCP_AUTH_URL set" do
          let(:auth_url) { "https://example.com" }

          it "should properly configure the oauth2 client" do
            expect(OAuth2::Client).to receive(:new).with(client_id, client_secret, hash_including(
              site: auth_url,
              authorize_url: described_class.const_get(:DEFAULT_AUTH_PATH),
              token_url: described_class.const_get(:DEFAULT_TOKEN_PATH),
            )).and_return(client)

            expect(subject.token).to eq(token)
          end
        end

        context "with HCP_AUTH_PATH set" do
          let(:auth_path) { "/auth/custom" }

          it "should properly configure the oauth2 client" do
            expect(OAuth2::Client).to receive(:new).with(client_id, client_secret, hash_including(
              site: described_class.const_get(:DEFAULT_AUTH_URL),
              authorize_url: auth_path,
              token_url: described_class.const_get(:DEFAULT_TOKEN_PATH),
            )).and_return(client)

            expect(subject.token).to eq(token)
          end
        end

        context "with HCP_TOKEN_PATH set" do
          let(:token_path) { "/token/custom" }

          it "should properly configure the oauth2 client" do
            expect(OAuth2::Client).to receive(:new).with(client_id, client_secret, hash_including(
              site: described_class.const_get(:DEFAULT_AUTH_URL),
              authorize_url: described_class.const_get(:DEFAULT_AUTH_PATH),
              token_url: token_path,
            )).and_return(client)

            expect(subject.token).to eq(token)
          end
        end
      end

      describe "#available?" do
        it "should return true" do
          expect(subject).to be_available
        end
      end
    end
  end
end
