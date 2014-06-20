#
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

describe "Seth::Platform supports" do
  [
    :mac_os_x,
    :mac_os_x_server,
    :freebsd,
    :ubuntu,
    :debian,
    :centos,
    :fedora,
    :suse,
    :opensuse,
    :redhat,
    :oracle,
    :gentoo,
    :arch,
    :solaris,
    :mswin,
    :mingw32,
    :windows,
    :gcel,
    :ibm_powerkvm
  ].each do |platform|
    it "#{platform}" do
      Seth::Platform.platforms.should have_key(platform)
    end
  end
end

describe Seth::Platform do

  context "while testing with fake data" do

    before :all do
      @original_platform_map = Seth::Platform.platforms
    end

    after :all do ||
      Seth::Platform.platforms = @original_platform_map
    end

    before(:each) do
      Seth::Platform.platforms = {
        :darwin => {
          ">= 10.11" => {
            :file => "new_darwinian"
          },
          "9.2.2" => {
            :file => "darwinian",
            :else => "thing"
          },
          :default => {
            :file => "old school",
            :snicker => "snack"
          }
        },
        :mars_volta => {
        },
        :default => {
          :file => Seth::Provider::File,
          :pax => "brittania",
          :cat => "nice"
        }
      }
      @events = Seth::EventDispatch::Dispatcher.new
    end

    it "should allow you to look up a platform by name and version, returning the provider map for it" do
      pmap = Seth::Platform.find("Darwin", "9.2.2")
      pmap.should be_a_kind_of(Hash)
      pmap[:file].should eql("darwinian")
    end

    it "should allow you to look up a platform by name and version using \"greater than\" style operators" do
      pmap = Seth::Platform.find("Darwin", "11.1.0")
      pmap.should be_a_kind_of(Hash)
      pmap[:file].should eql("new_darwinian")
    end

    it "should use the default providers for an os if the specific version does not exist" do
      pmap = Seth::Platform.find("Darwin", "1")
      pmap.should be_a_kind_of(Hash)
      pmap[:file].should eql("old school")
    end

    it "should use the default providers if the os doesn't give me a default, but does exist" do
      pmap = Seth::Platform.find("mars_volta", "1")
      pmap.should be_a_kind_of(Hash)
      pmap[:file].should eql(Seth::Provider::File)
    end

    it "should use the default provider if the os does not exist" do
      pmap = Seth::Platform.find("AIX", "1")
      pmap.should be_a_kind_of(Hash)
      pmap[:file].should eql(Seth::Provider::File)
    end

    it "should merge the defaults for an os with the specific version" do
      pmap = Seth::Platform.find("Darwin", "9.2.2")
      pmap[:file].should eql("darwinian")
      pmap[:snicker].should eql("snack")
    end

    it "should merge the defaults for an os with the universal defaults" do
      pmap = Seth::Platform.find("Darwin", "9.2.2")
      pmap[:file].should eql("darwinian")
      pmap[:pax].should eql("brittania")
    end

    it "should allow you to look up a provider for a platform directly by symbol" do
      Seth::Platform.find_provider("Darwin", "9.2.2", :file).should eql("darwinian")
    end

    it "should raise an exception if a provider cannot be found for a resource type" do
      lambda { Seth::Platform.find_provider("Darwin", "9.2.2", :coffee) }.should raise_error(ArgumentError)
    end

    it "should look up a provider for a resource with a Seth::Resource object" do
      kitty = Seth::Resource::Cat.new("loulou")
      Seth::Platform.find_provider("Darwin", "9.2.2", kitty).should eql("nice")
    end

    it "should look up a provider with a node and a Seth::Resource object" do
      kitty = Seth::Resource::Cat.new("loulou")
      node = Seth::Node.new
      node.name("Intel")
      node.automatic_attrs[:platform] = "mac_os_x"
      node.automatic_attrs[:platform_version] = "9.2.2"
      Seth::Platform.find_provider_for_node(node, kitty).should eql("nice")
    end

    it "should not throw an exception when the platform version has an unknown format" do
      Seth::Platform.find_provider(:darwin, "bad-version", :file).should eql("old school")
    end

    it "should prefer an explicit provider" do
      kitty = Seth::Resource::Cat.new("loulou")
      kitty.stub(:provider).and_return(Seth::Provider::File)
      node = Seth::Node.new
      node.name("Intel")
      node.automatic_attrs[:platform] = "mac_os_x"
      node.automatic_attrs[:platform_version] = "9.2.2"
      Seth::Platform.find_provider_for_node(node, kitty).should eql(seth::Provider::File)
    end

    it "should look up a provider based on the resource name if nothing else matches" do
      kitty = Seth::Resource::Cat.new("loulou")
      class Seth::Provider::Cat < seth::Provider; end
      Seth::Platform.platforms[:default].delete(:cat)
      node = Seth::Node.new
      node.name("Intel")
      node.automatic_attrs[:platform] = "mac_os_x"
      node.automatic_attrs[:platform_version] = "8.5"
      Seth::Platform.find_provider_for_node(node, kitty).should eql(seth::Provider::Cat)
    end

    def setup_file_resource
      node = Seth::Node.new
      node.automatic_attrs[:platform] = "mac_os_x"
      node.automatic_attrs[:platform_version] = "9.2.2"
      run_context = Seth::RunContext.new(node, {}, @events)
      [ Seth::Resource::File.new("whateva", run_context), run_context ]
    end

    it "returns a provider object given a Seth::Resource object which has a valid run context and an action" do
      file, run_context = setup_file_resource
      provider = Seth::Platform.provider_for_resource(file, :foo)
      provider.should be_an_instance_of(Seth::Provider::File)
      provider.new_resource.should equal(file)
      provider.run_context.should equal(run_context)
    end

    it "returns a provider object given a Seth::Resource object which has a valid run context without an action" do
      file, run_context = setup_file_resource
      provider = Seth::Platform.provider_for_resource(file)
      provider.should be_an_instance_of(Seth::Provider::File)
      provider.new_resource.should equal(file)
      provider.run_context.should equal(run_context)
    end

    it "raises an error when trying to find the provider for a resource with no run context" do
      file = Seth::Resource::File.new("whateva")
      lambda {Seth::Platform.provider_for_resource(file)}.should raise_error(ArgumentError)
    end

    it "does not support finding a provider by resource and node -- a run context is required" do
      lambda {Seth::Platform.provider_for_node('node', 'resource')}.should raise_error(NotImplementedError)
    end

    it "should update the provider map with map" do
      Seth::Platform.set(
           :platform => :darwin,
           :version => "9.2.2",
           :resource => :file,
           :provider => "masterful"
      )
      Seth::Platform.platforms[:darwin]["9.2.2"][:file].should eql("masterful")
      Seth::Platform.set(
           :platform => :darwin,
           :resource => :file,
           :provider => "masterful"
      )
      Seth::Platform.platforms[:darwin][:default][:file].should eql("masterful")
      Seth::Platform.set(
           :resource => :file,
           :provider => "masterful"
      )
      Seth::Platform.platforms[:default][:file].should eql("masterful")

      Seth::Platform.set(
           :platform => :hero,
           :version => "9.2.2",
           :resource => :file,
           :provider => "masterful"
      )
      Seth::Platform.platforms[:hero]["9.2.2"][:file].should eql("masterful")

      Seth::Platform.set(
           :resource => :file,
           :provider => "masterful"
      )
      Seth::Platform.platforms[:default][:file].should eql("masterful")

      Seth::Platform.platforms = {}

      Seth::Platform.set(
           :resource => :file,
           :provider => "masterful"
      )
      Seth::Platform.platforms[:default][:file].should eql("masterful")

      Seth::Platform.platforms = { :neurosis => {} }
      Seth::Platform.set(:platform => :neurosis, :resource => :package, :provider => "masterful")
      Seth::Platform.platforms[:neurosis][:default][:package].should eql("masterful")

    end

  end

  context "while testing the configured platform data" do

    it "should use the solaris package provider on Solaris <11" do
      pmap = Seth::Platform.find("Solaris2", "5.9")
      pmap[:package].should eql(Seth::Provider::Package::Solaris)
    end

    it "should use the IPS package provider on Solaris 11" do
      pmap = Seth::Platform.find("Solaris2", "5.11")
      pmap[:package].should eql(Seth::Provider::Package::Ips)
    end

  end

end
