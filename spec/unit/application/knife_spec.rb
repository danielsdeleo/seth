#
# Author:: AJ Christensen (<aj@junglist.gen.nz>)
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

require 'spec_helper'
require "#{seth_SPEC_DATA}/ceth_subcommand/test_yourself"

describe Seth::Application::ceth do
  include SpecHelpers::ceth

  before(:all) do
    class NoopcethCommand < Seth::ceth
      option :opt_with_default,
        :short => "-D VALUE",
        :long => "-optwithdefault VALUE",
        :default => "default-value"

      def run
      end
    end
  end

  before(:each) do
    # Prevent code from getting loaded on every test invocation.
    Seth::ceth.stub(:load_commands)

    @ceth = Seth::Application::ceth.new
    @ceth.stub(:puts)
    @ceth.stub(:trap)
    Seth::ceth.stub(:list_commands)
  end

  it "should exit 1 and print the options if no arguments are given at all" do
    with_argv([]) do
      lambda { @ceth.run }.should raise_error(SystemExit) { |e| e.status.should == 1 }
    end
  end

  it "should exit 2 if run without a sub command" do
    with_argv("--user", "adam") do
      Seth::Log.should_receive(:error).with(/you need to pass a sub\-command/i)
      lambda { @ceth.run }.should raise_error(SystemExit) { |e| e.status.should == 2 }
    end
  end

  it "should run a sub command with the applications command line option prototype" do
    with_argv(*%w{noop ceth command with some args}) do
      ceth = double(Seth::ceth)
      Seth::ceth.should_receive(:run).with(ARGV, @ceth.options).and_return(ceth)
      @ceth.should_receive(:exit).with(0)
      @ceth.run
    end
  end

  it "should set the colored output to false by default on windows and true otherwise" do
    with_argv(*%w{noop ceth command}) do
      @ceth.should_receive(:exit).with(0)
      @ceth.run
    end
    if windows?
      Seth::Config[:color].should be_false
    else
      Seth::Config[:color].should be_true
    end
  end

  describe "when given a path to the client key" do
    it "expands a relative path relative to the CWD" do
      relative_path = '.seth/client.pem'
      Dir.stub(:pwd).and_return(seth_SPEC_DATA)
      with_argv(*%W{noop ceth command -k #{relative_path}}) do
        @ceth.should_receive(:exit).with(0)
        @ceth.run
      end
      Seth::Config[:client_key].should == File.join(seth_SPEC_DATA, relative_path)
    end

    it "expands a ~/home/path to the correct full path" do
      home_path = '~/.seth/client.pem'
      with_argv(*%W{noop ceth command -k #{home_path}}) do
        @ceth.should_receive(:exit).with(0)
        @ceth.run
      end
      Seth::Config[:client_key].should == File.join(ENV['HOME'], '.seth/client.pem').gsub((File::ALT_SEPARATOR || '\\'), File::SEPARATOR)
    end

    it "does not expand a full path" do
      full_path = if windows?
        'C:/seth/client.pem'
      else
        '/etc/seth/client.pem'
      end
      with_argv(*%W{noop ceth command -k #{full_path}}) do
        @ceth.should_receive(:exit).with(0)
        @ceth.run
      end
      Seth::Config[:client_key].should == full_path
    end

  end

  describe "with environment configuration" do
    before do
      Seth::Config[:environment] = nil
    end

    it "should default to no environment" do
      with_argv(*%w{noop ceth command}) do
        @ceth.should_receive(:exit).with(0)
        @ceth.run
      end
      Seth::Config[:environment].should == nil
    end

    it "should load the environment from the config file" do
      config_file = File.join(seth_SPEC_DATA,"environment-config.rb")
      with_argv(*%W{noop ceth command -c #{config_file}}) do
        @ceth.should_receive(:exit).with(0)
        @ceth.run
      end
      Seth::Config[:environment].should == 'production'
    end

    it "should load the environment from the CLI options" do
      with_argv(*%W{noop ceth command -E development}) do
        @ceth.should_receive(:exit).with(0)
        @ceth.run
      end
      Seth::Config[:environment].should == 'development'
    end

    it "should override the config file environment with the CLI environment" do
      config_file = File.join(seth_SPEC_DATA,"environment-config.rb")
      with_argv(*%W{noop ceth command -c #{config_file} -E override}) do
        @ceth.should_receive(:exit).with(0)
        @ceth.run
      end
      Seth::Config[:environment].should == 'override'
    end

    it "should override the config file environment with the CLI environment regardless of order" do
      config_file = File.join(seth_SPEC_DATA,"environment-config.rb")
      with_argv(*%W{noop ceth command -E override -c #{config_file}}) do
        @ceth.should_receive(:exit).with(0)
        @ceth.run
      end
      Seth::Config[:environment].should == 'override'
    end

    it "should run a sub command with the applications command line option prototype" do
      with_argv(*%w{noop ceth command with some args}) do
        ceth = double(Seth::ceth)
        Seth::ceth.should_receive(:run).with(ARGV, @ceth.options).and_return(ceth)
        @ceth.should_receive(:exit).with(0)
        @ceth.run
      end
    end

  end
end
