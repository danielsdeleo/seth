#
# Author:: Adam Jacob (<adam@opscode.com>)
# Author:: Bryan McLellan <btm@loftninjas.org>
# Copyright:: Copyright (c) 2008, 2012 Opscode, Inc.
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

describe Seth::Resource::sethGem, "initialize" do

  before(:each) do
    @resource = Seth::Resource::sethGem.new("foo")
  end

  it "should return a Seth::Resource::sethGem" do
    @resource.should be_a_kind_of(Seth::Resource::sethGem)
  end

  it "should set the resource_name to :seth_gem" do
    @resource.resource_name.should eql(:seth_gem)
  end

  it "should set the provider to Seth::Provider::Package::Rubygems" do
    @resource.provider.should eql(Seth::Provider::Package::Rubygems)
  end
end

describe Seth::Resource::sethGem, "gem_binary" do
  before(:each) do
    expect(RbConfig::CONFIG).to receive(:[]).with('bindir').and_return("/opt/seth/embedded/bin")
    @resource = Seth::Resource::sethGem.new("foo")
  end

  it "should raise an exception when gem_binary is set" do
    lambda { @resource.gem_binary("/lol/cats/gem") }.should raise_error(ArgumentError)
  end

  it "should set the gem_binary based on computing it from RbConfig" do
    expect(@resource.gem_binary).to eql("/opt/seth/embedded/bin/gem")
  end
end
