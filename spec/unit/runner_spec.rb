
# Author:: Adam Jacob (<adam@opscode.com>)
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

class SnitchyProvider < Seth::Provider
  def self.all_actions_called
    @all_actions_called ||= []
  end

  def self.action_called(action)
    all_actions_called << action
  end

  def self.clear_action_record
    @all_actions_called = nil
  end

  def load_current_resource
    true
  end

  def action_first_action
    @new_resource.updated_by_last_action(true)
    self.class.action_called(:first)
  end

  def action_second_action
    @new_resource.updated_by_last_action(true)
    self.class.action_called(:second)
  end

  def action_third_action
    @new_resource.updated_by_last_action(true)
    self.class.action_called(:third)
  end

end

class FailureResource < Seth::Resource

  attr_accessor :action

  def initialize(*args)
    super
    @action = :fail
  end

  def provider
    FailureProvider
  end
end

class FailureProvider < Seth::Provider

  class SethClientFail < StandardError; end

  def load_current_resource
    true
  end

  def action_fail
    raise SethClientFail, "seth had an error of some sort"
  end
end

describe Seth::Runner do

  before(:each) do
    @node = Seth::Node.new
    @node.name "latte"
    @node.automatic[:platform] = "mac_os_x"
    @node.automatic[:platform_version] = "10.5.1"
    @events = Seth::EventDispatch::Dispatcher.new
    @run_context = Seth::RunContext.new(@node, seth::CookbookCollection.new({}), @events)
    @first_resource = Seth::Resource::Cat.new("loulou1", @run_context)
    @run_context.resource_collection << @first_resource
    Seth::Platform.set(
      :resource => :cat,
      :provider => Seth::Provider::SnakeOil
    )
    @runner = Seth::Runner.new(@run_context)
  end

  it "should pass each resource in the collection to a provider" do
    @run_context.resource_collection.should_receive(:execute_each_resource).once
    @runner.converge
  end

  it "should use the provider specified by the resource (if it has one)" do
    provider = Seth::Provider::Easy.new(@run_context.resource_collection[0], @run_context)
    # Expect provider to be called twice, because will fall back to old provider lookup
    @run_context.resource_collection[0].should_receive(:provider).twice.and_return(Seth::Provider::Easy)
    Seth::Provider::Easy.should_receive(:new).once.and_return(provider)
    @runner.converge
  end

  it "should use the platform provider if it has one" do
    Seth::Platform.should_receive(:find_provider_for_node).once.and_return(seth::Provider::SnakeOil)
    @runner.converge
  end

  it "should run the action for each resource" do
    Seth::Platform.should_receive(:find_provider_for_node).once.and_return(seth::Provider::SnakeOil)
    provider = Seth::Provider::SnakeOil.new(@run_context.resource_collection[0], @run_context)
    provider.should_receive(:action_sell).once.and_return(true)
    Seth::Provider::SnakeOil.should_receive(:new).once.and_return(provider)
    @runner.converge
  end

  it "should raise exceptions as thrown by a provider" do
    provider = Seth::Provider::SnakeOil.new(@run_context.resource_collection[0], @run_context)
    Seth::Provider::SnakeOil.stub(:new).once.and_return(provider)
    provider.stub(:action_sell).once.and_raise(ArgumentError)
    lambda { @runner.converge }.should raise_error(ArgumentError)
  end

  it "should not raise exceptions thrown by providers if the resource has ignore_failure set to true" do
    @run_context.resource_collection[0].stub(:ignore_failure).and_return(true)
    provider = Seth::Provider::SnakeOil.new(@run_context.resource_collection[0], @run_context)
    Seth::Provider::SnakeOil.stub(:new).once.and_return(provider)
    provider.stub(:action_sell).once.and_raise(ArgumentError)
    lambda { @runner.converge }.should_not raise_error
  end

  it "should retry with the specified delay if retries are specified" do
    @first_resource.retries 3
    provider = Seth::Provider::SnakeOil.new(@run_context.resource_collection[0], @run_context)
    Seth::Provider::SnakeOil.stub(:new).once.and_return(provider)
    provider.stub(:action_sell).and_raise(ArgumentError)
    @first_resource.should_receive(:sleep).with(2).exactly(3).times
    lambda { @runner.converge }.should raise_error(ArgumentError)
  end

  it "should execute immediate actions on changed resources" do
    notifying_resource = Seth::Resource::Cat.new("peanut", @run_context)
    notifying_resource.action = :purr # only action that will set updated on the resource

    @run_context.resource_collection << notifying_resource
    @first_resource.action = :nothing # won't be updated unless notified by other resource

    notifying_resource.notifies(:purr, @first_resource, :immediately)

    @runner.converge

    @first_resource.should be_updated
  end

  it "should follow a chain of actions" do
    @first_resource.action = :nothing

    middle_resource = Seth::Resource::Cat.new("peanut", @run_context)
    middle_resource.action = :nothing
    @run_context.resource_collection << middle_resource
    middle_resource.notifies(:purr, @first_resource, :immediately)

    last_resource = Seth::Resource::Cat.new("snuffles", @run_context)
    last_resource.action = :purr
    @run_context.resource_collection << last_resource
    last_resource.notifies(:purr, middle_resource, :immediately)

    @runner.converge

    last_resource.should be_updated   # by action(:purr)
    middle_resource.should be_updated # by notification from last_resource
    @first_resource.should be_updated # by notification from middle_resource
  end

  it "should execute delayed actions on changed resources" do
    @first_resource.action = :nothing
    second_resource = Seth::Resource::Cat.new("peanut", @run_context)
    second_resource.action = :purr

    @run_context.resource_collection << second_resource
    second_resource.notifies(:purr, @first_resource, :delayed)

    @runner.converge

    @first_resource.should be_updated
  end

  it "should execute delayed notifications when a failure occurs in the seth client run" do
    @first_resource.action = :nothing
    second_resource = Seth::Resource::Cat.new("peanut", @run_context)
    second_resource.action = :purr

    @run_context.resource_collection << second_resource
    second_resource.notifies(:purr, @first_resource, :delayed)

    third_resource = FailureResource.new("explode", @run_context)
    @run_context.resource_collection << third_resource

    lambda {@runner.converge}.should raise_error(FailureProvider::SethClientFail)

    @first_resource.should be_updated
  end

  it "should execute delayed notifications when a failure occurs in a notification" do
    @first_resource.action = :nothing
    second_resource = Seth::Resource::Cat.new("peanut", @run_context)
    second_resource.action = :purr

    @run_context.resource_collection << second_resource

    third_resource = FailureResource.new("explode", @run_context)
    third_resource.action = :nothing
    @run_context.resource_collection << third_resource

    second_resource.notifies(:fail, third_resource, :delayed)
    second_resource.notifies(:purr, @first_resource, :delayed)

    lambda {@runner.converge}.should raise_error(FailureProvider::SethClientFail)

    @first_resource.should be_updated
  end

  it "should execute delayed notifications when a failure occurs in multiple notifications" do
    @first_resource.action = :nothing
    second_resource = Seth::Resource::Cat.new("peanut", @run_context)
    second_resource.action = :purr

    @run_context.resource_collection << second_resource

    third_resource = FailureResource.new("explode", @run_context)
    third_resource.action = :nothing
    @run_context.resource_collection << third_resource

    fourth_resource = FailureResource.new("explode again", @run_context)
    fourth_resource.action = :nothing
    @run_context.resource_collection << fourth_resource

    second_resource.notifies(:fail, third_resource, :delayed)
    second_resource.notifies(:fail, fourth_resource, :delayed)
    second_resource.notifies(:purr, @first_resource, :delayed)

    exception = nil
    begin
      @runner.converge
    rescue => e
      exception = e
    end
    exception.should be_a(Seth::Exceptions::MultipleFailures)

    expected_message =<<-E
Multiple failures occurred:
* FailureProvider::SethClientFail occurred in delayed notification: [explode] (dynamically defined) had an error: FailureProvider::sethClientFail: seth had an error of some sort
* FailureProvider::SethClientFail occurred in delayed notification: [explode again] (dynamically defined) had an error: FailureProvider::sethClientFail: seth had an error of some sort
E
    exception.message.should == expected_message

    @first_resource.should be_updated
  end

  it "does not duplicate delayed notifications" do
    SnitchyProvider.clear_action_record

    Seth::Platform.set(
      :resource => :cat,
      :provider => SnitchyProvider
    )

    @first_resource.action = :nothing

    second_resource = Seth::Resource::Cat.new("peanut", @run_context)
    second_resource.action = :first_action
    @run_context.resource_collection << second_resource

    third_resource = Seth::Resource::Cat.new("snickers", @run_context)
    third_resource.action = :first_action
    @run_context.resource_collection << third_resource

    second_resource.notifies(:second_action, @first_resource, :delayed)
    second_resource.notifies(:third_action, @first_resource, :delayed)

    third_resource.notifies(:second_action, @first_resource, :delayed)
    third_resource.notifies(:third_action, @first_resource, :delayed)

    @runner.converge
    # resources 2 and 3 call :first_action in the course of normal resource
    # execution, and schedule delayed actions :second and :third on the first
    # resource. The duplicate actions should "collapse" to a single notification
    # and order should be preserved.
    SnitchyProvider.all_actions_called.should == [:first, :first, :second, :third]
  end

  it "executes delayed notifications in the order they were declared" do
    SnitchyProvider.clear_action_record

    Seth::Platform.set(
      :resource => :cat,
      :provider => SnitchyProvider
    )

    @first_resource.action = :nothing

    second_resource = Seth::Resource::Cat.new("peanut", @run_context)
    second_resource.action = :first_action
    @run_context.resource_collection << second_resource

    third_resource = Seth::Resource::Cat.new("snickers", @run_context)
    third_resource.action = :first_action
    @run_context.resource_collection << third_resource

    second_resource.notifies(:second_action, @first_resource, :delayed)
    second_resource.notifies(:second_action, @first_resource, :delayed)

    third_resource.notifies(:third_action, @first_resource, :delayed)
    third_resource.notifies(:third_action, @first_resource, :delayed)

    @runner.converge
    SnitchyProvider.all_actions_called.should == [:first, :first, :second, :third]
  end

  it "does not fire notifications if the resource was not updated by the last action executed" do
    # REGRESSION TEST FOR seth-1452
    SnitchyProvider.clear_action_record

    Seth::Platform.set(
      :resource => :cat,
      :provider => SnitchyProvider
    )

    @first_resource.action = :first_action

    second_resource = Seth::Resource::Cat.new("peanut", @run_context)
    second_resource.action = :nothing
    @run_context.resource_collection << second_resource

    third_resource = Seth::Resource::Cat.new("snickers", @run_context)
    third_resource.action = :nothing
    @run_context.resource_collection << third_resource

    @first_resource.notifies(:second_action, second_resource, :immediately)
    second_resource.notifies(:third_action, third_resource, :immediately)

    @runner.converge

    # All of the resources should only fire once:
    SnitchyProvider.all_actions_called.should == [:first, :second, :third]

    # all of the resources should be marked as updated for reporting purposes
    @first_resource.should be_updated
    second_resource.should be_updated
    third_resource.should be_updated
  end

  it "should check a resource's only_if and not_if if notified by another resource" do
    @first_resource.action = :buy

    only_if_called_times = 0
    @first_resource.only_if {only_if_called_times += 1; true}

    not_if_called_times = 0
    @first_resource.not_if {not_if_called_times += 1; false}

    second_resource = Seth::Resource::Cat.new("carmel", @run_context)
    @run_context.resource_collection << second_resource
    second_resource.notifies(:purr, @first_resource, :delayed)
    second_resource.action = :purr

    # hits only_if first time when the resource is run in order, second on notify
    @runner.converge

    only_if_called_times.should == 2
    not_if_called_times.should == 2
  end

  it "should resolve resource references in notifications when resources are defined lazily" do
    @first_resource.action = :nothing

    lazy_resources = lambda {
      last_resource = Seth::Resource::Cat.new("peanut", @run_context)
      @run_context.resource_collection << last_resource
      last_resource.notifies(:purr, @first_resource.to_s, :delayed)
      last_resource.action = :purr
    }
    second_resource = Seth::Resource::RubyBlock.new("myblock", @run_context)
    @run_context.resource_collection << second_resource
    second_resource.block { lazy_resources.call }

    @runner.converge

    @first_resource.should be_updated
  end

end

