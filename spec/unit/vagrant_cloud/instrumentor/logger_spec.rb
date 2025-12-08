# Copyright IBM Corp. 2014, 2025
# SPDX-License-Identifier: MIT

require "spec_helper"
require "vagrant_cloud"

describe VagrantCloud::Instrumentor::Logger do
  let(:logger) { double("logger") }

  before { allow(subject).to receive(:logger).and_return(logger) }

  it "should be a subclass of Core" do
    expect(described_class.ancestors).to include(VagrantCloud::Instrumentor::Core)
  end

  describe "#instrument" do
    before do
      allow(logger).to receive(:debug).and_yield
      allow(logger).to receive(:info).and_yield
      allow(logger).to receive(:error).and_yield
    end

    context "errors" do
      let(:name) { "test.error" }

      it "should output error message when event type is error" do
        expect(logger).to receive(:error)
        subject.instrument(name)
      end

      it "should include namespace and event type in output" do
        expect(logger).to receive(:error) do |&b|
          expect(b.call).to match(/test ERROR/)
        end
        subject.instrument(name)
      end

      it "should include optional error message if provided" do
        expect(logger).to receive(:error) do |&b|
          expect(b.call).to match(/test ERROR custom message/)
        end
        subject.instrument(name, error: "custom message")
      end

      it "should not proceed any farther" do
        expect(logger).not_to receive(:info)
        expect(logger).not_to receive(:debug)
        subject.instrument(name)
      end
    end

    context "non-excon namespaced events" do
      let(:name) { "test.action" }
      let(:params) { {} }

      after { subject.instrument(name, params) }

      it "should include namespace in info output" do
        expect(logger).to receive(:info) do |&b|
          expect(b.call).to include("test")
        end
      end

      it "should include namespace in debug output" do
        expect(logger).to receive(:debug) do |&b|
          expect(b.call).to include("test")
        end
      end

      it "should include the event name in the info output upcased" do
        expect(logger).to receive(:info) do |&b|
          expect(b.call).to include("ACTION")
        end
      end

      it "should include the event name in the debug output upcased" do
        expect(logger).to receive(:debug) do |&b|
          expect(b.call).to include("ACTION")
        end
      end

      it "should format output to the logger" do
        # debug format
        expect(subject).to receive(:format_output).with(params)
        # info format
        expect(subject).to receive(:format_output).with(anything)
      end

      context "when params include content" do
        let(:params) { {value: true, testing: "a-value"} }

        it "should include params in the info output" do
          expect(logger).to receive(:info) do |&b|
            result = b.call
            expect(result).to include("testing=\"a-value\"")
            expect(result).to include("value=true")
          end
        end

        it "should include params in the debug output" do
          expect(logger).to receive(:debug) do |&b|
            result = b.call
            expect(result).to include("testing=\"a-value\"")
            expect(result).to include("value=true")
          end
        end
      end
    end

    context "excon namespaced events" do
      let(:name) { "excon.action" }
      let(:params) { {data: nil} }

      after { subject.instrument(name, params) }

      it "should call #excon to filter parameters" do
        expect(subject).to receive(:excon).with(anything, params).and_return({})
      end

      it "should send event type to #excon" do
        expect(subject).to receive(:excon).with("action", anything).and_return({})
      end

      it "should output all parameters via debug" do
        allow(subject).to receive(:format_output)
        expect(subject).to receive(:format_output).with(params)
      end
    end
  end

  describe "excon" do
    let(:action) { double("action") }
    let(:params) { {} }
    let(:redacted) { described_class.const_get(:REDACTED) }

    it "should return hash with duration" do
      expect(subject.excon(action, params)).to have_key(:duration)
    end

    context "when parameters include password" do
      let(:params) { {password: "my-password"} }

      it "should redact the password value" do
        subject.excon(action, params)
        expect(params[:password]).to eq(redacted)
      end
    end

    context "when parameters include proxy password" do
      let(:params) { {proxy: {password: "my-password"}} }

      it "should redact the password value" do
        subject.excon(action, params)
        expect(params.dig(:proxy, :password)).to eq(redacted)
      end
    end

    context "when parameters include access token" do
      let(:params) { {access_token: "my-token"} }

      it "should redact the access token value" do
        subject.excon(action, params)
        expect(params[:access_token]).to eq(redacted)
      end
    end

    context "when parameters include authorization header" do
      let(:params) { {headers: {"Authorization" => "value"}} }

      it "should redact the authorization header value" do
        subject.excon(action, params)
        expect(params.dig(:headers, "Authorization")).to eq(redacted)
      end
    end

    context "when parameters include proxy authorization header" do
      let(:params) { {headers: {"Proxy-Authorization" => "value"}} }

      it "should redact the authorization header value" do
        subject.excon(action, params)
        expect(params.dig(:headers, "Proxy-Authorization")).to eq(redacted)
      end
    end
  end
end
