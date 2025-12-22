# Copyright IBM Corp. 2014, 2025
# SPDX-License-Identifier: MIT

require "spec_helper"
require "vagrant_cloud"

describe VagrantCloud::Instrumentor::Collection do
  describe "#initialize" do
    it "should be a Core type" do
      expect(subject).to be_a(VagrantCloud::Instrumentor::Core)
    end

    it "should have a logger instrumentor by default" do
      expect(subject.instrumentors.first).to be_a(VagrantCloud::Instrumentor::Logger)
    end

    it "should accept additional instrumentors" do
      addition = VagrantCloud::Instrumentor::Core.new
      instance = described_class.new(instrumentors: [addition])
      expect(instance.instrumentors).to include(addition)
    end

    it "should accept single additional instrumentor" do
      addition = VagrantCloud::Instrumentor::Core.new
      instance = described_class.new(instrumentors: addition)
      expect(instance.instrumentors).to include(addition)
    end
  end

  describe "#add" do
    it "should add a new instrumentor" do
      addition = VagrantCloud::Instrumentor::Core.new
      subject.add(addition)
      expect(subject.instrumentors).to include(addition)
    end

    it "should return self" do
      addition = VagrantCloud::Instrumentor::Core.new
      expect(subject.add(addition)).to eq(subject)
    end

    it "should only add an instrumentor instance once" do
      addition = VagrantCloud::Instrumentor::Core.new
      subject.add(addition).add(addition)
      expect(subject.instrumentors.count{|i| i == addition}).to eq(1)
    end

    it "should error if instance is not an instrumentor" do
      expect { subject.add("string") }.to raise_error(TypeError)
    end

    it "should freeze instrumentors after adding" do
      addition = VagrantCloud::Instrumentor::Core.new
      subject.add(addition).add(addition)
      expect(subject.instrumentors).to be_frozen
    end
  end

  describe "#remove" do
    it "should remove an instrumentor" do
      addition = VagrantCloud::Instrumentor::Core.new
      subject.add(addition).add(addition)
      expect(subject.instrumentors).to include(addition)
      subject.remove(addition)
      expect(subject.instrumentors).not_to include(addition)
    end

    it "should return self" do
      expect(subject.remove(nil)).to eq(subject)
    end

    it "should freeze instrumentors after removing" do
      addition = VagrantCloud::Instrumentor::Core.new
      subject.add(addition).add(addition)
      subject.remove(addition)
      expect(subject.instrumentors).to be_frozen
    end
  end

  describe "#subscribe" do
    it "should add a new subscription entry" do
      expect(subject.subscriptions.size).to eq(0)
      subject.subscribe("event", proc{})
      expect(subject.subscriptions.size).to eq(1)
    end

    it "should freeze subscriptions after subscribing" do
      subject.subscribe("event", proc{})
      expect(subject.subscriptions).to be_frozen
    end

    it "should return self" do
      expect(subject.subscribe("event", proc{})).to eq(subject)
    end

    it "should error if callable is not provided" do
      expect { subject.subscribe("event") }.to raise_error(TypeError)
    end

    it "should error if non-callable is provided" do
      expect { subject.subscribe("event", :thing) }.to raise_error(TypeError)
    end

    it "should error if callable and block are provided" do
      expect { subject.subscribe("event", proc{}){} }.to raise_error(ArgumentError)
    end

    it "should add with callable argument" do
      expect { subject.subscribe("event", proc{}) }.not_to raise_error
    end

    it "should add with block" do
      expect { subject.subscribe("event"){} }.not_to raise_error
    end
  end

  describe "#unsubscribe" do
    it "should remove entry using callable instance" do
      callable = proc{}
      subject.subscribe("event", callable)
      expect(subject.subscriptions.count).to eq(1)
      subject.unsubscribe(callable)
      expect(subject.subscriptions).to be_empty
    end

    it "should freeze subscriptions after remove" do
      callable = proc{}
      subject.subscribe("event", callable)
      expect(subject.subscriptions.count).to eq(1)
      subject.unsubscribe(callable)
      expect(subject.subscriptions).to be_frozen
    end

    it "should return self" do
      callable = proc{}
      subject.subscribe("event", callable)
      expect(subject.subscriptions.count).to eq(1)
      expect(subject.unsubscribe(callable)).to eq(subject)
    end
  end

  describe "#instrument" do
    let(:logger) { double("logger") }
    let(:event) { "event" }
    let(:params) { {} }

    before do
      allow(VagrantCloud::Instrumentor::Logger).
        to receive(:new).and_return(logger)
      allow(logger).to receive(:instrument)
    end

    it "should call the logger instrumentor" do
      expect(logger).to receive(:instrument).with(event, params)
      subject.instrument(event, params)
    end

    it "should yield when a block is provided" do
      run = false
      subject.instrument(event, params) do
        run = true
      end
      expect(run).to be_truthy
    end

    it "should return the result of the block when provided" do
      expect(subject.instrument(event, params){ :result }).to eq(:result)
    end

    it "should add timing information to params" do
      subject.instrument(event, params)
      expect(params).to have_key(:timing)
    end

    it "should provide duration timing" do
      expect(Time).to receive(:now).and_return(Time.now - 5)
      expect(Time).to receive(:now).and_call_original
      subject.instrument(event, params)
      expect(params.dig(:timing, :duration)).to be_within(0.01).of(5)
    end

    context "when a subscription is added with exact name match" do
      it "should call the subscription" do
        run = false
        callable = proc { run = true }
        subject.subscribe(event, callable)
        subject.instrument(event, params)
        expect(run).to be_truthy
      end
    end

    context "when a subscription is added with regex name match" do
      it "should call the subscription" do
        run = false
        callable = proc { run = true }
        subject.subscribe(/ev/, callable)
        subject.instrument(event, params)
        expect(run).to be_truthy
      end
    end

    context "when a subscription is added with exact name not matching" do
      it "should not call the subscription" do
        run = false
        callable = proc { run = true }
        subject.subscribe("other", callable)
        subject.instrument(event, params)
        expect(run).to be_falsey
      end
    end

    context "when a subscription is added with regex name not matching" do
      it "should not call the subscription" do
        run = false
        callable = proc { run = true }
        subject.subscribe(/ot/, callable)
        subject.instrument(event, params)
        expect(run).to be_falsey
      end
    end
  end
end
