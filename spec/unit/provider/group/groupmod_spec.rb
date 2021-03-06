#
# Author:: Dan Crosta (<dcrosta@late.am>)
# Copyright:: Copyright (c) 2012 OpsCode, Inc.
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

describe Seth::Provider::Group::Groupmod do
    before do
      @node = Seth::Node.new
      @events = Seth::EventDispatch::Dispatcher.new
      @run_context = Seth::RunContext.new(@node, {}, @events)
      @new_resource = Seth::Resource::Group.new("wheel")
      @new_resource.gid 123
      @new_resource.members %w{lobster rage fist}
      @new_resource.append false
      @provider = Seth::Provider::Group::Groupmod.new(@new_resource, @run_context)
    end

  describe "manage_group" do
    describe "when determining the current group state" do
      it "should raise an error if the required binary /usr/sbin/group doesn't exist" do
        File.should_receive(:exists?).with("/usr/sbin/group").and_return(false)
        lambda { @provider.load_current_resource }.should raise_error(Seth::Exceptions::Group)
      end
      it "should raise an error if the required binary /usr/sbin/user doesn't exist" do
        File.should_receive(:exists?).with("/usr/sbin/group").and_return(true)
        File.should_receive(:exists?).with("/usr/sbin/user").and_return(false)
        lambda { @provider.load_current_resource }.should raise_error(Seth::Exceptions::Group)
      end

      it "shouldn't raise an error if the required binaries exist" do
        File.stub(:exists?).and_return(true)
        lambda { @provider.load_current_resource }.should_not raise_error
      end
    end

    describe "after the group's current state is known" do
      before do
        @current_resource = @new_resource.dup
        @provider.current_resource = @current_resource
      end

      describe "when no group members are specified and append is not set" do
        before do
          @new_resource.append(false)
          @new_resource.members([])
        end

        it "logs a message and sets group's members to 'none', then removes existing group members" do
          Seth::Log.should_receive(:debug).with("group[wheel] setting group members to: none")
          @provider.should_receive(:shell_out!).with("group mod -n wheel_bak wheel")
          @provider.should_receive(:shell_out!).with("group add -g '123' -o wheel")
          @provider.should_receive(:shell_out!).with("group del wheel_bak")
          @provider.manage_group
        end
      end

      describe "when no group members are specified and append is set" do
        before do
          @new_resource.append(true)
          @new_resource.members([])
        end

        it "logs a message and does not modify group membership" do
          Seth::Log.should_receive(:debug).with("group[wheel] not changing group members, the group has no members to add")
          @provider.should_not_receive(:shell_out!)
          @provider.manage_group
        end
      end

      describe "when removing some group members" do
        before do
          @new_resource.append(false)
          @new_resource.members(%w{ lobster })
        end

        it "updates group membership correctly" do
          Seth::Log.stub(:debug)
          @provider.should_receive(:shell_out!).with("group mod -n wheel_bak wheel")
          @provider.should_receive(:shell_out!).with("user mod -G wheel lobster")
          @provider.should_receive(:shell_out!).with("group add -g '123' -o wheel")
          @provider.should_receive(:shell_out!).with("group del wheel_bak")
          @provider.manage_group
        end
      end
    end
  end

  describe "create_group" do
    describe "when creating a new group" do
      before do
        @current_resource = Seth::Resource::Group.new("wheel")
        @provider.current_resource = @current_resource
      end

      it "should run a group add command and some user mod commands" do
        @provider.should_receive(:shell_out!).with("group add -g '123' wheel")
        @provider.should_receive(:shell_out!).with("user mod -G wheel lobster")
        @provider.should_receive(:shell_out!).with("user mod -G wheel rage")
        @provider.should_receive(:shell_out!).with("user mod -G wheel fist")
        @provider.create_group
      end
    end
  end

  describe "remove_group" do
    describe "when removing an existing group" do
      before do
        @current_resource = @new_resource.dup
        @provider.current_resource = @current_resource
      end

      it "should run a group del command" do
        @provider.should_receive(:shell_out!).with("group del wheel")
        @provider.remove_group
      end
    end
  end
end
