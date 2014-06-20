#
# Author:: Bryan McLellan <btm@opscode.com>
# Copyright:: Copyright (c) 2012 Opscode, Inc.
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
require 'net/ssh'
require 'net/ssh/multi'

describe Seth::ceth::Ssh do
  before(:each) do
    Seth::Config[:client_key] = seth_SPEC_DATA + "/ssl/private_key.pem"
  end

  before do
    @ceth = Seth::ceth::Ssh.new
    @ceth.merge_configs
    @ceth.config[:attribute] = "fqdn"
    @node_foo = Seth::Node.new
    @node_foo.automatic_attrs[:fqdn] = "foo.example.org"
    @node_foo.automatic_attrs[:ipaddress] = "10.0.0.1"
    @node_bar = Seth::Node.new
    @node_bar.automatic_attrs[:fqdn] = "bar.example.org"
    @node_bar.automatic_attrs[:ipaddress] = "10.0.0.2"
  end

  describe "#configure_session" do
    context "manual is set to false (default)" do
      before do
        @ceth.config[:manual] = false
        @query = Seth::Search::Query.new
      end

      def configure_query(node_array)
        @query.stub(:search).and_return([node_array])
        Seth::Search::Query.stub(:new).and_return(@query)
      end

      def self.should_return_specified_attributes
        it "returns an array of the attributes specified on the command line OR config file, if only one is set" do
          @ceth.config[:attribute] = "ipaddress"
          @ceth.config[:override_attribute] = "ipaddress"
          configure_query([@node_foo, @node_bar])
          @ceth.should_receive(:session_from_list).with([['10.0.0.1', nil], ['10.0.0.2', nil]])
          @ceth.configure_session
        end

        it "returns an array of the attributes specified on the command line even when a config value is set" do
          @ceth.config[:attribute] = "config_file" # this value will be the config file
          @ceth.config[:override_attribute] = "ipaddress" # this is the value of the command line via #configure_attribute
          configure_query([@node_foo, @node_bar])
          @ceth.should_receive(:session_from_list).with([['10.0.0.1', nil], ['10.0.0.2', nil]])
          @ceth.configure_session
        end
      end

      it "searchs for and returns an array of fqdns" do
        configure_query([@node_foo, @node_bar])
        @ceth.should_receive(:session_from_list).with([
          ['foo.example.org', nil],
          ['bar.example.org', nil]
        ])
        @ceth.configure_session
      end

      should_return_specified_attributes

      context "when cloud hostnames are available" do
        before do
          @node_foo.automatic_attrs[:cloud][:public_hostname] = "ec2-10-0-0-1.compute-1.amazonaws.com"
          @node_bar.automatic_attrs[:cloud][:public_hostname] = "ec2-10-0-0-2.compute-1.amazonaws.com"
        end

        it "returns an array of cloud public hostnames" do
          configure_query([@node_foo, @node_bar])
          @ceth.should_receive(:session_from_list).with([
            ['ec2-10-0-0-1.compute-1.amazonaws.com', nil],
            ['ec2-10-0-0-2.compute-1.amazonaws.com', nil]
          ])
          @ceth.configure_session
        end

        should_return_specified_attributes
      end

      it "should raise an error if no host are found" do
          configure_query([ ])
          @ceth.ui.should_receive(:fatal)
          @ceth.should_receive(:exit).with(10)
          @ceth.configure_session
      end

      context "when there are some hosts found but they do not have an attribute to connect with" do
        before do
          @query.stub(:search).and_return([[@node_foo, @node_bar]])
          @node_foo.automatic_attrs[:fqdn] = nil
          @node_bar.automatic_attrs[:fqdn] = nil
          Seth::Search::Query.stub(:new).and_return(@query)
        end

        it "should raise a specific error (seth-3402)" do
          @ceth.ui.should_receive(:fatal).with(/^2 nodes found/)
          @ceth.should_receive(:exit).with(10)
          @ceth.configure_session
        end
      end
    end

    context "manual is set to true" do
      before do
        @ceth.config[:manual] = true
      end

      it "returns an array of provided values" do
        @ceth.instance_variable_set(:@name_args, ["foo.example.org bar.example.org"])
        @ceth.should_receive(:session_from_list).with(['foo.example.org', 'bar.example.org'])
        @ceth.configure_session
      end
    end
  end

  describe "#configure_attribute" do
    before do
      Seth::Config[:ceth][:ssh_attribute] = nil
      @ceth.config[:attribute] = nil
    end

    it "should return fqdn by default" do
      @ceth.configure_attribute
      @ceth.config[:attribute].should == "fqdn"
    end

    it "should return the value set in the configuration file" do
      Seth::Config[:ceth][:ssh_attribute] = "config_file"
      @ceth.configure_attribute
      @ceth.config[:attribute].should == "config_file"
    end

    it "should return the value set on the command line" do
      @ceth.config[:attribute] = "command_line"
      @ceth.configure_attribute
      @ceth.config[:attribute].should == "command_line"
    end

    it "should set override_attribute to the value of attribute from the command line" do
      @ceth.config[:attribute] = "command_line"
      @ceth.configure_attribute
      @ceth.config[:attribute].should == "command_line"
      @ceth.config[:override_attribute].should == "command_line"
    end

    it "should set override_attribute to the value of attribute from the config file" do
      Seth::Config[:ceth][:ssh_attribute] = "config_file"
      @ceth.configure_attribute
      @ceth.config[:attribute].should == "config_file"
      @ceth.config[:override_attribute].should == "config_file"
    end

    it "should prefer the command line over the config file for the value of override_attribute" do
      Seth::Config[:ceth][:ssh_attribute] = "config_file"
      @ceth.config[:attribute] = "command_line"
      @ceth.configure_attribute
      @ceth.config[:override_attribute].should == "command_line"
    end
  end

  describe "#session_from_list" do
    before :each do
      @ceth.instance_variable_set(:@longest, 0)
      ssh_config = {:timeout => 50, :user => "locutus", :port => 23 }
      Net::SSH.stub(:configuration_for).with('the.b.org').and_return(ssh_config)
    end

    it "uses the port from an ssh config file" do
      @ceth.session_from_list([['the.b.org', nil]])
      @ceth.session.servers[0].port.should == 23
    end

    it "uses the port from a cloud attr" do
      @ceth.session_from_list([['the.b.org', 123]])
      @ceth.session.servers[0].port.should == 123
    end

    it "uses the user from an ssh config file" do
      @ceth.session_from_list([['the.b.org', 123]])
      @ceth.session.servers[0].user.should == "locutus"
    end
  end

  describe "#ssh_command" do
    let(:execution_channel) { double(:execution_channel, :on_data => nil) }
    let(:session_channel) { double(:session_channel, :request_pty => nil)}

    let(:execution_channel2) { double(:execution_channel, :on_data => nil) }
    let(:session_channel2) { double(:session_channel, :request_pty => nil)}

    let(:session) { double(:session, :loop => nil) }

    let(:command) { "false" }

    before do
      execution_channel.
        should_receive(:on_request).
        and_yield(nil, double(:data_stream, :read_long => exit_status))

      session_channel.
        should_receive(:exec).
        with(command).
        and_yield(execution_channel, true)

      execution_channel2.
        should_receive(:on_request).
        and_yield(nil, double(:data_stream, :read_long => exit_status2))

      session_channel2.
        should_receive(:exec).
        with(command).
        and_yield(execution_channel2, true)

      session.
        should_receive(:open_channel).
        and_yield(session_channel).
        and_yield(session_channel2)
    end

    context "both connections return 0" do
      let(:exit_status) { 0 }
      let(:exit_status2) { 0 }

      it "returns a 0 exit code" do
        @ceth.ssh_command(command, session).should == 0
      end
    end

    context "the first connection returns 1 and the second returns 0" do
      let(:exit_status) { 1 }
      let(:exit_status2) { 0 }

      it "returns a non-zero exit code" do
        @ceth.ssh_command(command, session).should == 1
      end
    end

    context "the first connection returns 1 and the second returns 2" do
      let(:exit_status) { 1 }
      let(:exit_status2) { 2 }

      it "returns a non-zero exit code" do
        @ceth.ssh_command(command, session).should == 2
      end
    end
  end

  describe "#run" do
    before do
      @query = Seth::Search::Query.new
      @query.should_receive(:search).and_return([[@node_foo]])
      Seth::Search::Query.stub(:new).and_return(@query)
      @ceth.stub(:ssh_command).and_return(exit_code)
      @ceth.name_args = ['*:*', 'false']
    end

    context "with an error" do
      let(:exit_code) { 1 }

      it "should exit with a non-zero exit code" do
        @ceth.should_receive(:exit).with(exit_code)
        @ceth.run
      end
    end

    context "with no error" do
      let(:exit_code) { 0 }

      it "should not exit" do
        @ceth.should_not_receive(:exit)
        @ceth.run
      end
    end
  end

  describe "#configure_password" do
    before do
      @ceth.config.delete(:ssh_password_ng)
      @ceth.config.delete(:ssh_password)
    end

    context "when setting ssh_password_ng from ceth ssh" do
      # in this case ssh_password_ng exists, but ssh_password does not
      it "should prompt for a password when ssh_passsword_ng is nil"  do
        @ceth.config[:ssh_password_ng] = nil
        @ceth.should_receive(:get_password).and_return("mysekretpassw0rd")
        @ceth.configure_password
        @ceth.config[:ssh_password].should == "mysekretpassw0rd"
      end

      it "should set ssh_password to false if ssh_password_ng is false"  do
        @ceth.config[:ssh_password_ng] = false
        @ceth.should_not_receive(:get_password)
        @ceth.configure_password
        @ceth.config[:ssh_password].should be_false
      end

      it "should set ssh_password to ssh_password_ng if we set a password" do
        @ceth.config[:ssh_password_ng] = "mysekretpassw0rd"
        @ceth.should_not_receive(:get_password)
        @ceth.configure_password
        @ceth.config[:ssh_password].should == "mysekretpassw0rd"
      end
    end

    context "when setting ssh_password from ceth bootstrap / ceth * server create" do
      # in this case ssh_password exists, but ssh_password_ng does not
      it "should set ssh_password to nil when ssh_password is nil" do
        @ceth.config[:ssh_password] = nil
        @ceth.should_not_receive(:get_password)
        @ceth.configure_password
        @ceth.config[:ssh_password].should be_nil
      end

      it "should set ssh_password to false when ssh_password is false" do
        @ceth.config[:ssh_password] = false
        @ceth.should_not_receive(:get_password)
        @ceth.configure_password
        @ceth.config[:ssh_password].should be_false
      end

      it "should set ssh_password to ssh_password if we set a password" do
        @ceth.config[:ssh_password] = "mysekretpassw0rd"
        @ceth.should_not_receive(:get_password)
        @ceth.configure_password
        @ceth.config[:ssh_password].should == "mysekretpassw0rd"
      end
    end
    context "when setting ssh_password in the config variable" do
      before(:each) do
        Seth::Config[:ceth][:ssh_password] = "my_ceth_passw0rd"
      end
      context "when setting ssh_password_ng from ceth ssh" do
        # in this case ssh_password_ng exists, but ssh_password does not
        it "should prompt for a password when ssh_passsword_ng is nil"  do
          @ceth.config[:ssh_password_ng] = nil
          @ceth.should_receive(:get_password).and_return("mysekretpassw0rd")
          @ceth.configure_password
          @ceth.config[:ssh_password].should == "mysekretpassw0rd"
        end

        it "should set ssh_password to the configured ceth.rb value if ssh_password_ng is false"  do
          @ceth.config[:ssh_password_ng] = false
          @ceth.should_not_receive(:get_password)
          @ceth.configure_password
          @ceth.config[:ssh_password].should == "my_ceth_passw0rd"
        end

        it "should set ssh_password to ssh_password_ng if we set a password" do
          @ceth.config[:ssh_password_ng] = "mysekretpassw0rd"
          @ceth.should_not_receive(:get_password)
          @ceth.configure_password
          @ceth.config[:ssh_password].should == "mysekretpassw0rd"
        end
      end

      context "when setting ssh_password from ceth bootstrap / ceth * server create" do
        # in this case ssh_password exists, but ssh_password_ng does not
        it "should set ssh_password to the configured ceth.rb value when ssh_password is nil" do
          @ceth.config[:ssh_password] = nil
          @ceth.should_not_receive(:get_password)
          @ceth.configure_password
          @ceth.config[:ssh_password].should == "my_ceth_passw0rd"
        end

        it "should set ssh_password to the configured ceth.rb value when ssh_password is false" do
          @ceth.config[:ssh_password] = false
          @ceth.should_not_receive(:get_password)
          @ceth.configure_password
          @ceth.config[:ssh_password].should == "my_ceth_passw0rd"
        end

        it "should set ssh_password to ssh_password if we set a password" do
          @ceth.config[:ssh_password] = "mysekretpassw0rd"
          @ceth.should_not_receive(:get_password)
          @ceth.configure_password
          @ceth.config[:ssh_password].should == "mysekretpassw0rd"
        end
      end
    end
  end
end
