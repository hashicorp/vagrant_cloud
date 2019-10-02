require 'spec_helper'
require 'vagrant_cloud'

describe VagrantCloud::Response::Search do
  let(:client) { double("client", access_token: nil) }
  let(:account) { VagrantCloud::Account.new(client: client) }
  let(:params) { {} }
  let(:result) { {boxes: boxes} }
  let(:boxes) { [] }
  let(:searcher) { VagrantCloud::Search.new(account: account) }

  let(:subject) { described_class.new(account: account, params: params, **result) }

  before do
    allow(client).to receive(:is_a?).with(VagrantCloud::Client).and_return(true)
    allow(VagrantCloud::Search).to receive(:new).and_return(searcher)
  end

  describe "#initialize" do
    it "should error when account is not provided" do
      expect { described_class.new(params: params, **result) }.
        to raise_error(ArgumentError)
    end

    it "should error when params are not provided" do
      expect { described_class.new(account: account, **result) }.
        to raise_error(ArgumentError)
    end

    it "should error when account is not the right type" do
      expect { described_class.new(account: "value", params: params, **result) }.
        to raise_error(TypeError)
    end

    it "should load boxes" do
      expect_any_instance_of(described_class).to receive(:reload_boxes)
      subject
    end
  end

  describe "#page" do
    it "defaults to page 1" do
      expect(subject.page).to eq(1)
    end

    context "when page is set in params" do
      let(:params) { {page: 5} }

      it "should return the page value" do
        expect(subject.page).to eq(5)
      end
    end
  end

  describe "#previous" do
    it "should raise error when no previous page is available" do
      expect { subject.previous }.to raise_error(ArgumentError)
    end

    context "with previous pages available" do
      let(:params) { {page: 5} }
      let(:response) { double("response") }

      before { allow(searcher).to receive(:execute).and_return(response) }

      it "should request previous page through a searcher" do
        expect(searcher).to receive(:prev_page)
        subject.previous
      end
    end
  end

  describe "#next" do
    let(:response) { double("response") }

    before { allow(searcher).to receive(:execute).and_return(response) }

    it "should request next page through a searcher" do
      expect(searcher).to receive(:next_page)
      subject.next
    end
  end

  describe "#boxes" do
    let(:boxes) { [{tag: "org/box", name: "box", username: "org"}] }
    let(:organization) { VagrantCloud::Organization.
        new(account: account, username: "org") }

    before { allow(account).to receive(:organization).
        with(name: "org").and_return(organization) }

    it "should have a boxes count of 1" do
      expect(subject.boxes.count).to eq(1)
    end

    it "should contain a Box instance" do
      expect(subject.boxes.first).to be_a(VagrantCloud::Box)
    end

    it "should population the organization" do
      expect(subject.boxes.first.organization.boxes.first).to eq(subject.boxes.first)
    end
  end
end
