require "spec_helper"
require "vagrant_cloud"

describe VagrantCloud::Instrumentor::Core do
  context "#instrument" do
    it "should raise NotImplementedError" do
      expect { subject.instrument }.to raise_error(NotImplementedError)
    end
  end
end
