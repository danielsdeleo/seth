#
# Author:: Adam Jacob (<adam@opscode.com>)
# Author:: Tyler Cloke (<tyler@opscode.com>)
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

describe Seth::Resource::RemoteFile do

  before(:each) do
    @resource = Seth::Resource::RemoteFile.new("fakey_fakerton")
  end

  describe "initialize" do
    it "should create a new Seth::Resource::RemoteFile" do
      @resource.should be_a_kind_of(Seth::Resource)
      @resource.should be_a_kind_of(Seth::Resource::File)
      @resource.should be_a_kind_of(Seth::Resource::RemoteFile)
    end
  end

  it "says its provider is RemoteFile when the source is an absolute URI" do
    @resource.source("http://www.google.com/robots.txt")
    @resource.provider.should == Seth::Provider::RemoteFile
    Seth::Platform.find_provider(:noplatform, 'noversion', @resource).should == seth::Provider::RemoteFile
  end


  describe "source" do
    it "does not have a default value for 'source'" do
      @resource.source.should eql([])
    end

    it "should accept a URI for the remote file source" do
      @resource.source "http://opscode.com/"
      @resource.source.should eql([ "http://opscode.com/" ])
    end

    it "should accept a delayed evalutator (string) for the remote file source" do
      @resource.source Seth::DelayedEvaluator.new {"http://opscode.com/"}
      @resource.source.should eql([ "http://opscode.com/" ])
    end

    it "should accept an array of URIs for the remote file source" do
      @resource.source([ "http://opscode.com/", "http://puppetlabs.com/" ])
      @resource.source.should eql([ "http://opscode.com/", "http://puppetlabs.com/" ])
    end

    it "should accept a delated evaluator (array) for the remote file source" do
      @resource.source Seth::DelayedEvaluator.new { [ "http://opscode.com/", "http://puppetlabs.com/" ] }
      @resource.source.should eql([ "http://opscode.com/", "http://puppetlabs.com/" ])
    end

    it "should accept an multiple URIs as arguments for the remote file source" do
      @resource.source("http://opscode.com/", "http://puppetlabs.com/")
      @resource.source.should eql([ "http://opscode.com/", "http://puppetlabs.com/" ])
    end

    it "should only accept a single argument if a delayed evalutor is used" do
      lambda {
        @resource.source("http://opscode.com/", Seth::DelayedEvaluator.new {"http://opscode.com/"})
      }.should raise_error(Seth::Exceptions::InvalidRemoteFileURI)
    end

    it "should only accept a single array item if a delayed evalutor is used" do
      lambda {
        @resource.source(["http://opscode.com/", Seth::DelayedEvaluator.new {"http://opscode.com/"}])
      }.should raise_error(Seth::Exceptions::InvalidRemoteFileURI)
    end

    it "does not accept a non-URI as the source" do
      lambda { @resource.source("not-a-uri") }.should raise_error(Seth::Exceptions::InvalidRemoteFileURI)
    end

    it "does not accept a non-URI as the source when read from a delayed evaluator" do
      lambda {
        @resource.source(Seth::DelayedEvaluator.new {"not-a-uri"})
        @resource.source
      }.should raise_error(Seth::Exceptions::InvalidRemoteFileURI)
    end

    it "should raise an exception when source is an empty array" do
      lambda { @resource.source([]) }.should raise_error(ArgumentError)
    end

  end

  describe "checksum" do
    it "should accept a string for the checksum object" do
      @resource.checksum "asdf"
      @resource.checksum.should eql("asdf")
    end

    it "should default to nil" do
      @resource.checksum.should == nil
    end
  end

  describe "ftp_active_mode" do
    it "should accept a boolean for the ftp_active_mode object" do
      @resource.ftp_active_mode true
      @resource.ftp_active_mode.should be_true
    end

    it "should default to false" do
      @resource.ftp_active_mode.should be_false
    end
  end

  describe "conditional get options" do
    it "defaults to using etags and last modified" do
      @resource.use_etags.should be_true
      @resource.use_last_modified.should be_true
    end

    it "enable or disables etag and last modified options as a group" do
      @resource.use_conditional_get(false)
      @resource.use_etags.should be_false
      @resource.use_last_modified.should be_false

      @resource.use_conditional_get(true)
      @resource.use_etags.should be_true
      @resource.use_last_modified.should be_true
    end

    it "disables etags indivdually" do
      @resource.use_etags(false)
      @resource.use_etags.should be_false
      @resource.use_last_modified.should be_true
    end

    it "disables last modified individually" do
      @resource.use_last_modified(false)
      @resource.use_last_modified.should be_false
      @resource.use_etags.should be_true
    end

  end

  describe "when it has group, mode, owner, source, and checksum" do
    before do
      if Seth::Platform.windows?
        @resource.path("C:/temp/origin/file.txt")
        @resource.rights(:read, "Everyone")
        @resource.deny_rights(:full_control, "Clumsy_Sam")
      else
        @resource.path("/this/path/")
        @resource.group("pokemon")
        @resource.mode("0664")
        @resource.owner("root")
      end
      @resource.source("https://www.google.com/images/srpr/logo3w.png")
      @resource.checksum("1"*26)
    end

    it "describes its state" do
      state = @resource.state
      if Seth::Platform.windows?
        puts state
        state[:rights].should == [{:permissions => :read, :principals => "Everyone"}]
        state[:deny_rights].should == [{:permissions => :full_control, :principals => "Clumsy_Sam"}]
      else
        state[:group].should == "pokemon"
        state[:mode].should == "0664"
        state[:owner].should == "root"
        state[:checksum].should == "1"*26
      end
    end

    it "returns the path as its identity" do
      if Seth::Platform.windows?
        @resource.identity.should == "C:/temp/origin/file.txt"
      else
        @resource.identity.should == "/this/path/"
      end
    end
  end
end
