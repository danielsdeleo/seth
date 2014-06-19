require 'spec_helper'

describe Seth::Knife::TagList do
  before(:each) do
    Seth::Config[:node_name] = "webmonkey.example.com"
    @knife = Seth::Knife::TagList.new
    @knife.name_args = [ Seth::Config[:node_name], "sadtag" ]

    @node = Seth::Node.new
    @node.stub :save
    @node.tags << "sadtag" << "happytag"
    Seth::Node.stub(:load).and_return @node
  end

  describe "run" do
    it "can list tags on a node" do
      expected = %w(sadtag happytag)
      @node.tags.should == expected
      @knife.should_receive(:output).with(expected)
      @knife.run
    end
  end
end
