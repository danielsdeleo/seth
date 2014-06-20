#
# Author:: Cary Penniman (<cary@rightscale.com>)
# Copyright:: Copyright (c) 2008 Opscode, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'spec_helper'

describe Seth::Provider::Log::sethLog do

  before(:each) do
    @log_str = "this is my test string to log"
    @node = Seth::Node.new
    @events = Seth::EventDispatch::Dispatcher.new
    @run_context = Seth::RunContext.new(@node, {}, @events)
  end

  it "should be registered with the default platform hash" do
    Seth::Platform.platforms[:default][:log].should_not be_nil
  end

  it "should write the string to the Seth::Log object at default level (info)" do
      @new_resource = Seth::Resource::Log.new(@log_str)
      @provider = Seth::Provider::Log::sethLog.new(@new_resource, @run_context)
      Seth::Log.should_receive(:info).with(@log_str).and_return(true)
      @provider.action_write
  end

  it "should write the string to the Seth::Log object at debug level" do
      @new_resource = Seth::Resource::Log.new(@log_str)
      @new_resource.level :debug
      @provider = Seth::Provider::Log::sethLog.new(@new_resource, @run_context)
      Seth::Log.should_receive(:debug).with(@log_str).and_return(true)
      @provider.action_write
  end

  it "should write the string to the Seth::Log object at info level" do
      @new_resource = Seth::Resource::Log.new(@log_str)
      @new_resource.level :info
      @provider = Seth::Provider::Log::sethLog.new(@new_resource, @run_context)
      Seth::Log.should_receive(:info).with(@log_str).and_return(true)
      @provider.action_write
  end

  it "should write the string to the Seth::Log object at warn level" do
      @new_resource = Seth::Resource::Log.new(@log_str)
      @new_resource.level :warn
      @provider = Seth::Provider::Log::sethLog.new(@new_resource, @run_context)
      Seth::Log.should_receive(:warn).with(@log_str).and_return(true)
      @provider.action_write
  end

  it "should write the string to the Seth::Log object at error level" do
      @new_resource = Seth::Resource::Log.new(@log_str)
      @new_resource.level :error
      @provider = Seth::Provider::Log::sethLog.new(@new_resource, @run_context)
      Seth::Log.should_receive(:error).with(@log_str).and_return(true)
      @provider.action_write
  end

  it "should write the string to the Seth::Log object at fatal level" do
      @new_resource = Seth::Resource::Log.new(@log_str)
      @new_resource.level :fatal
      @provider = Seth::Provider::Log::sethLog.new(@new_resource, @run_context)
      Seth::Log.should_receive(:fatal).with(@log_str).and_return(true)
      @provider.action_write
  end

  it "should not update the resource if the message was not written to the log" do
      Seth::Log.level = :fatal
      @new_resource = Seth::Resource::Log.new(@log_str)
      @new_resource.level :info
      @provider = Seth::Provider::Log::sethLog.new(@new_resource, @run_context)
      @provider.action_write
      @new_resource.updated.should be_false
  end

  it "should update the resource if the message has been written to the log" do
      Seth::Log.level = :debug
      @new_resource = Seth::Resource::Log.new(@log_str)
      @new_resource.level :info
      @provider = Seth::Provider::Log::sethLog.new(@new_resource, @run_context)
      @provider.action_write
      @new_resource.updated.should be_true
  end

end
