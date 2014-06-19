require File.expand_path('../../spec_helper', __FILE__)

describe "Seth::ShellOut deprecation notices" do
  it "logs a warning when initializing a new Seth::ShellOut object" do
    Seth::Log.should_receive(:warn).with("Chef::ShellOut is deprecated, please use Mixlib::ShellOut")
    Seth::Log.should_receive(:warn).with(/Called from\:/)
    Seth::ShellOut.new("pwd")
  end
end

describe "Seth::Exceptions::ShellCommandFailed deprecation notices" do

  it "logs a warning when referencing the constant Seth::Exceptions::ShellCommandFailed" do
    Seth::Log.should_receive(:warn).with("Chef::Exceptions::ShellCommandFailed is deprecated, use Mixlib::ShellOut::ShellCommandFailed")
    Seth::Log.should_receive(:warn).with(/Called from\:/)
    Seth::Exceptions::ShellCommandFailed
  end
end
