require 'spec_helper'
require 'vagrant_cloud'

describe VagrantCloud::Data::NilClass do
  let(:subject) { described_class.instance }

  it "should be a singleton" do
    expect(described_class.ancestors).to include(Singleton)
  end

  it "should be nil?" do
    expect(subject.nil?).to be_truthy
  end

  it "should == nil" do
    expect(subject == nil).to be_truthy
  end

  it "should === nil" do
    expect(subject === nil).to be_truthy
  end

  it "should equal? nil" do
    expect(subject.equal?(nil)).to be_truthy
  end

  it "should convert to 0" do
    expect(subject.to_i).to eq(0)
  end

  it "should convert to 0.0" do
    expect(subject.to_f).to eq(0.0)
  end

  it "should convert to empty array" do
    expect(subject.to_a).to eq([])
  end

  it "should convert to empty hash" do
    expect(subject.to_h).to eq({})
  end

  it "should convert to empty string" do
    expect(subject.to_s).to eq("")
  end

  it "should & to false" do
    expect(subject & :value).to be_falsey
  end

  it "should | to false" do
    expect(subject | :value).to be_falsey
  end

  it "should ^ to false" do
    expect(subject ^ :value).to be_falsey
  end

  it "should inspect to nil string" do
    expect(subject.inspect).to eq("nil")
  end
end

describe VagrantCloud::Data do
  describe "#initialize" do
    it "should accept no arguments when creating" do
      expect { described_class.new }.not_to raise_error
    end

    it "should accept arguments when creating" do
      expect { described_class.new(value: true) }.not_to raise_error
    end
  end

  describe "#[]" do
    it "should provide access to arguments" do
      instance = described_class.new(value: 1)
      expect(instance[:value]).to eq(1)
    end

    it "should return custom nil when argument is not defined" do
      instance = described_class.new(value: 1)
      expect(instance[:other_value]).to eq(VagrantCloud::Data::Nil)
    end
  end
end

describe VagrantCloud::Data::Immutable do
  context "with required attributes" do
    let(:described_class) do
      @c ||= Class.new(VagrantCloud::Data::Immutable) do
        attr_required :password
      end
    end

    it "should error if required argument is not provided" do
      expect { described_class.new }.to raise_error(ArgumentError)
    end

    it "should not error if required argument is provided" do
      expect { described_class.new(password: "value") }.not_to raise_error
    end

    it "should add an accessor to retrieve the value" do
      instance = described_class.new(password: "value")
      expect(instance.password).to eq("value")
    end

    it "should retrieve value via [] using a symbol" do
      instance = described_class.new(password: "value")
      expect(instance[:password]).to eq("value")
    end

    it "should retrieve value via [] using a string" do
      instance = described_class.new(password: "value")
      expect(instance["password"]).to eq("value")
    end

    it "should not allow value to be modified" do
      instance = described_class.new(password: "value")
      expect { instance.password.replace("new-value") }.to raise_error(FrozenError)
    end
  end

  context "with optional attributes" do
    let(:described_class) do
      @c ||= Class.new(VagrantCloud::Data::Immutable) do
        attr_optional :username
      end
    end

    it "should not error if argument is not provided" do
      expect { described_class.new(username: "value") }.not_to raise_error
    end

    it "should add an accessor to retrieve the value" do
      instance = described_class.new(username: "value")
      expect(instance.username).to eq("value")
    end

    it "should retrieve value via [] using a symbol" do
      instance = described_class.new(username: "value")
      expect(instance[:username]).to eq("value")
    end

    it "should retrieve value via [] using a string" do
      instance = described_class.new(username: "value")
      expect(instance["username"]).to eq("value")
    end

    it "should not allow value to be modified" do
      instance = described_class.new(username: "value")
      expect { instance.username.replace("new-value") }.to raise_error(FrozenError)
    end

    it "should return custom nil via accessor when unset" do
      instance = described_class.new
      expect(instance.username).to eq(VagrantCloud::Data::Nil)
    end

    it "should return custom nil via []" do
      instance = described_class.new
      expect(instance[:username]).to eq(VagrantCloud::Data::Nil)
    end
  end

  context "with optional and required attributes" do
    let(:described_class) do
      @c ||= Class.new(VagrantCloud::Data::Immutable) do
        attr_required :password
        attr_optional :username
      end
    end

    it "should error if invalid argument is provided" do
      expect { described_class.new(password: "pass", other: true) }.to raise_error(ArgumentError)
    end

    it "should error if no arguments are provided" do
      expect { described_class.new }.to raise_error(ArgumentError)
    end

    it "should error if only optional argument is provided" do
      expect { described_class.new(username: "user") }.to raise_error(ArgumentError)
    end

    it "should not error if required argument is provided" do
      expect { described_class.new(password: "pass") }.not_to raise_error
    end

    it "should not error if both required and optional arguments are provided" do
      expect { described_class.new(password: "pass", username: "user") }.not_to raise_error
    end
  end
end

describe VagrantCloud::Data::Mutable do
  let(:username) { "U" }
  let(:password) { "P" }

  context ".load" do
    let(:described_class) do
      @c ||= Class.new(VagrantCloud::Data::Mutable) do
        attr_reader :key
        attr_required :password
        attr_optional :username
        def initialize(key:, **opts)
          super(**opts)
          @key = key
        end
      end
    end

    it "should create a new instance" do
      data = {password: "pass", key: "key"}
      instance = described_class.load(data)
      expect(instance).to be_a(described_class)
    end

    it "should set the information provided in the data hash" do
      data = {password: "pass", key: "key"}
      instance = described_class.load(data)
      expect(instance.password).to eq("pass")
      expect(instance.key).to eq("key")
    end

    it "should ignore extra information in the hash" do
      data = {password: "pass", key: "key", invalid: true}
      instance = described_class.load(data)
      expect(instance.password).to eq("pass")
      expect(instance.key).to eq("key")
    end
  end

  describe "#freeze" do
    it "should return self" do
      expect(subject.freeze).to eq(subject)
    end

    it "should not freeze" do
      expect(subject.freeze).not_to be_frozen
    end
  end

  context "with no mutables defined" do
    let(:described_class) do
      @c ||= Class.new(VagrantCloud::Data::Mutable) do
        attr_required :password
        attr_optional :username
      end
    end

    let(:subject) { described_class.new(username: username, password: password) }

    it "should not allow setting optional value" do
      expect { subject.username = "new-value" }.to raise_error(NoMethodError)
    end

    it "should not allow setting required value" do
      expect { subject.password = "new-value" }.to raise_error(NoMethodError)
    end
  end

  context "with mutables defined" do
    let(:described_class) do
      @c ||= Class.new(VagrantCloud::Data::Mutable) do
        attr_required :password
        attr_optional :username

        attr_mutable :username, :password
      end
    end

    let(:subject) { described_class.new(username: username, password: password) }

    it "should allow setting optional value" do
      expect { subject.username = "new-value" }.not_to raise_error
    end

    it "should allow setting required value" do
      expect { subject.password = "new-value" }.not_to raise_error
    end

    it "should return updated optional value" do
      expect(subject.username).to eq(username)
      subject.username = "new-value"
      expect(subject.username).to eq("new-value")
    end

    it "should return updated required value" do
      expect(subject.password).to eq(password)
      subject.password = "new-value"
      expect(subject.password).to eq("new-value")
    end

    context "#dirty?" do
      it "should mark the instance as dirty when value is updated" do
        subject.username = "new-value"
        expect(subject.dirty?).to be_truthy
      end

      it "should mark the field as dirty with value is updated" do
        subject.username = "new-value"
        expect(subject.dirty?(:username)).to be_truthy
      end

      it "should not mark other fields dirty when not updated" do
        subject.username = "new-value"
        expect(subject.dirty?(:username)).to be_truthy
        expect(subject.dirty?(:password)).to be_falsey
      end
    end

    context "#clean!" do
      it "should make a dirty instance clean" do
        subject.username = "new-value"
        expect(subject.dirty?).to be_truthy
        subject.clean!
        expect(subject.dirty?).to be_falsey
      end

      it "should make clean values non-modifyable" do
        subject.username = "new-value"
        subject.clean!
        expect { subject.username.replace("testing") }.to raise_error(FrozenError)
      end
    end

    context "#clean" do
      it "should update values with provided data" do
        expect(subject.username).to eq(username)
        expect(subject.password).to eq(password)
        subject.clean(data: {username: "new-user", password: "new-pass"})
        expect(subject.username).to eq("new-user")
        expect(subject.password).to eq("new-pass")
      end

      it "should update instance so it is non-dirty" do
        expect(subject.dirty?).to be_falsey
        subject.clean(data: {username: "new-user", password: "new-pass"})
        expect(subject.dirty?).to be_falsey
      end

      it "should ignore fields of data provided" do
        expect(subject.username).to eq(username)
        expect(subject.password).to eq(password)
        subject.clean(data: {username: "new-user", password: "new-pass"}, ignores: :password)
        expect(subject.username).to eq("new-user")
        expect(subject.password).to eq(password)
      end

      it "should only update requested fields of data provided" do
        expect(subject.username).to eq(username)
        expect(subject.password).to eq(password)
        subject.clean(data: {username: "new-user", password: "new-pass"}, only: :password)
        expect(subject.username).to eq(username)
        expect(subject.password).to eq("new-pass")
      end

      it "should make clean values non-modifyable" do
        subject.clean(data: {username: "new-user", password: "new-pass"}, only: :password)
        subject.clean!
        expect { subject.username.replace("testing") }.to raise_error(FrozenError)
      end

      it "should error if data provided is not a hash" do
        expect { subject.clean(data: nil) }.to raise_error(TypeError)
      end
    end
  end
end
