#
# Author:: Bryan McLellan <btm@loftninjas.org>
# Copyright:: Copyright (c) 2014 Seth Software, Inc.
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

describe Seth::Provider::Package::Windows, :windows_only do
  let(:node) { double('Seth::Node') }
  let(:events) { double('Seth::Events').as_null_object }  # mock all the methods
  let(:run_context) { double('Seth::RunContext', :node => node, :events => events) }
  let(:new_resource) { Seth::Resource::WindowsPackage.new("calculator.msi") }
  let(:provider) { Seth::Provider::Package::Windows.new(new_resource, run_context) }

  describe "load_current_resource" do
    before(:each) do
      Seth::Util::PathHelper.stub(:validate_path)
      provider.stub(:package_provider).and_return(double('package_provider',
          :installed_version => "1.0", :package_version => "2.0"))
    end

    it "creates a current resource with the name of the new resource" do
      provider.load_current_resource
      expect(provider.current_resource).to be_a(Seth::Resource::WindowsPackage)
      expect(provider.current_resource.name).to eql("calculator.msi")
    end

    it "sets the current version if the package is installed" do
      provider.load_current_resource
      expect(provider.current_resource.version).to eql("1.0")
    end

    it "sets the version to be installed" do
      provider.load_current_resource
      expect(provider.new_resource.version).to eql("2.0")
    end

    it "checks that the source path is valid" do
      expect(Seth::Util::PathHelper).to receive(:validate_path)
      provider.load_current_resource
    end
  end

  describe "package_provider" do
    it "sets the package provider to MSI if the the installer type is :msi" do
      provider.stub(:installer_type).and_return(:msi)
      expect(provider.package_provider).to be_a(Seth::Provider::Package::Windows::MSI)
    end

    it "raises an error if the installer_type is unknown" do
      provider.stub(:installer_type).and_return(:apt_for_windows)
      expect { provider.package_provider }.to raise_error
    end
  end

  describe "installer_type" do
    it "it returns @installer_type if it is set" do
      provider.new_resource.installer_type("downeaster")
      expect(provider.installer_type).to eql("downeaster")
    end

    it "sets installer_type to msi if the source ends in .msi" do
      provider.new_resource.source("microsoft_installer.msi")
      expect(provider.installer_type).to eql(:msi)
    end

    it "raises an error if it cannot determine the installer type" do
      provider.new_resource.installer_type(nil)
      provider.new_resource.source("tomfoolery.now")
      expect { provider.installer_type }.to raise_error(ArgumentError)
    end
  end
end
