require 'spec_helper'
require 'vagrant_cloud'

describe VagrantCloud::Search do
  let(:account) { double("account", client: client_account) }
  let(:client) { double("client", access_token: nil) }
  let(:client_account) { double("client_account") }
  let(:client_with_token) { double("client_with_token", access_token: access_token) }
  let(:access_token) { double("access_token") }
  let(:response) { {boxes: boxes} }
  let(:boxes) { [] }

  before do
    allow(VagrantCloud::Client).to receive(:new).
      with(hash_including(access_token: nil)).and_return(client)
    allow(VagrantCloud::Client).to receive(:new).
      with(hash_including(access_token: access_token)).and_return(client_with_token)
    allow(account).to receive(:is_a?).with(VagrantCloud::Account).and_return(true)
    allow(client).to receive(:is_a?).with(VagrantCloud::Client).and_return(true)
    allow(client_with_token).to receive(:request).and_return({})
    allow(client).to receive(:search).and_return(response)
  end

  describe "#initialize" do
    it "should create a new instance without an access token" do
      expect(subject.account.client).to eq(client)
    end

    it "should create a new instance with a custom access token" do
      instance = described_class.new(access_token: access_token)
      expect(instance.account.client).to eq(client_with_token)
    end

    it "should create a new instance with an account" do
      instance = described_class.new(account: account)
      expect(instance.account.client).to eq(client_account)
    end

    it "should create a new instance with a client" do
      instance = described_class.new(client: client)
      expect(instance.account.client).to eq(client)
    end

    it "should error when more than one argument is provided" do
      expect { described_class.new(client: client, access_token: access_token) }.
        to raise_error(ArgumentError)
    end

    it "should error when client is not a client instance" do
      expect { described_class.new(client: "value") }.
        to raise_error(TypeError)
    end

    it "should error when account is not an account instance" do
      expect { described_class.new(account: "value") }.
        to raise_error(TypeError)
    end
  end

  describe "#search" do
    it "should execute the search request" do
      expect(subject).to receive(:execute)
      subject.search
    end

    it "should set instance to active after a search" do
      expect(subject.active?).to be_falsey
      subject.search
      expect(subject.active?).to be_truthy
    end

    it "should return a search response" do
      expect(subject.search).to be_a(VagrantCloud::Response::Search)
    end
  end

  describe "#next_page" do
    it "should error without active search" do
      expect { subject.next_page }.to raise_error(ArgumentError)
    end

    context "with active search" do
      before { subject.search }

      it "should not produce an error" do
        expect { subject.next_page }.not_to raise_error
      end

      it "should increment the page requested" do
        expect(subject).to receive(:execute).and_call_original
        expect(client).to receive(:search).with(hash_including(page: 2)).
          and_return(response)
        subject.next_page
      end

      it "should return a search response" do
        expect(subject.next_page).to be_a(VagrantCloud::Response::Search)
      end

      it "should persist the page number" do
        subject.next_page
        expect(client).to receive(:search).with(hash_including(page: 3)).
          and_return(response)
        subject.next_page
      end
    end
  end

  describe "#prev_page" do
    it "should error without active search" do
      expect { subject.prev_page }.to raise_error(ArgumentError)
    end

    context "with active search" do
      before { subject.search }

      it "should not produce an error" do
        expect { subject.prev_page }.not_to raise_error
      end

      it "should maintain page 1 when decrementing page is less than 1" do
        subject.prev_page
        expect(client).to receive(:search).with(hash_including(page: 1)).
          and_return(response)
        subject.prev_page
      end

      it "should return a search response" do
        expect(subject.prev_page).to be_a(VagrantCloud::Response::Search)
      end

      context "with active search on page 10" do
        before { subject.search(page: 10) }

        it "should request results from page 9" do
          expect(client).to receive(:search).with(hash_including(page: 9)).
            and_return(response)
          subject.prev_page
        end

        it "should persist page value and request page 8" do
          subject.prev_page
          expect(client).to receive(:search).with(hash_including(page: 8)).
            and_return(response)
          subject.prev_page
        end
      end
    end
  end

  describe "#active?" do
    context "without active search" do
      it "should be false" do
        expect(subject.active?).to be_falsey
      end
    end

    context "with active search" do
      before { subject.search }

      it "should be true" do
        expect(subject.active?).to be_truthy
      end
    end
  end

  describe "#clear!" do
    it "should return self" do
      expect(subject.clear!).to eq(subject)
    end

    it "should not be active after clearing" do
      subject.clear!
      expect(subject.active?).to be_falsey
    end

    context "with active search" do
      before { subject.search }

      it "should not be active after clearing" do
        expect(subject.active?).to be_truthy
        subject.clear!
        expect(subject.active?).to be_falsey
      end
    end
  end

  describe "#seed" do
    it "should return self" do
      expect(subject.seed(query: "test")).to eq(subject)
    end

    it "should make search instance active" do
      expect(subject.active?).to be_falsey
      subject.seed(query: "test")
      expect(subject.active?).to be_truthy
    end

    it "should not execute a request" do
      expect(subject).not_to receive(:execute)
      subject.seed(query: "test")
    end
  end

  describe "#from_response" do
    it "should yield a new search instance" do
      subject.from_response(subject.search) do |s|
        expect(s).not_to eq(subject)
        expect(s).to be_a(described_class)
      end
    end
  end
end
