#
# Author:: AJ Christensen (<aj@junglist.gen.nz>)
# Author:: Mark Mzyk (mmzyk@opscode.com)
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

describe Seth::Application do
  before do
    @original_argv = ARGV.dup
    ARGV.clear
    Seth::Log.logger = Logger.new(StringIO.new)
    @app = Seth::Application.new
    @app.stub(:trap)
    Dir.stub(:chdir).and_return(0)
    @app.stub(:reconfigure)
    Seth::Log.init(STDERR)
  end

  after do
    ARGV.replace(@original_argv)
  end

  describe "reconfigure" do
    before do
      @app = Seth::Application.new
      @app.stub(:configure_seth).and_return(true)
      @app.stub(:configure_logging).and_return(true)
      @app.stub(:configure_proxy_environment_variables).and_return(true)
    end

    it "should configure seth" do
      @app.should_receive(:configure_seth).and_return(true)
      @app.reconfigure
    end

    it "should configure logging" do
      @app.should_receive(:configure_logging).and_return(true)
      @app.reconfigure
    end

    it "should configure environment variables" do
      @app.should_receive(:configure_proxy_environment_variables).and_return(true)
      @app.reconfigure
    end
  end

  describe Seth::Application do
    before do
      @app = Seth::Application.new
    end

    describe "run" do
      before do
        @app.stub(:setup_application).and_return(true)
        @app.stub(:run_application).and_return(true)
        @app.stub(:configure_seth).and_return(true)
        @app.stub(:configure_logging).and_return(true)
      end

      it "should reconfigure the application before running" do
        @app.should_receive(:reconfigure).and_return(true)
        @app.run
      end

      it "should setup the application before running it" do
        @app.should_receive(:setup_application).and_return(true)
        @app.run
      end

      it "should run the actual application" do
        @app.should_receive(:run_application).and_return(true)
        @app.run
      end
    end
  end

  describe "configure_seth" do
    before do
      # Silence warnings when no config file exists
      Seth::Log.stub(:warn)

      @app = Seth::Application.new
      #Seth::Config.stub(:merge!).and_return(true)
      @app.stub(:parse_options).and_return(true)
    end

    it "should parse the commandline options" do
      @app.should_receive(:parse_options).and_return(true)
      @app.config[:config_file] = "/etc/seth/default.rb" #have a config file set, to prevent triggering error block
      @app.configure_seth
    end

    describe "when a config_file is present" do
      let(:config_content) { "rspec_ran('true')" }
      let(:config_location) { "/etc/seth/default.rb" }

      let(:config_location_pathname) do
        p = Pathname.new(config_location)
        p.stub(:realpath).and_return(config_location)
        p
      end

      before do
        @app.config[:config_file] = config_location

        # force let binding to get evaluated or else we stub Pathname.new before we try to use it.
        config_location_pathname
        Pathname.stub(:new).with(config_location).and_return(config_location_pathname)
        File.should_receive(:read).
          with(config_location).
          and_return(config_content)
      end

      it "should configure seth::config from a file" do
        Seth::Config.should_receive(:from_string).with(config_content, config_location)
        @app.configure_seth
      end

      it "should merge the local config hash into seth::config" do
        #File.should_receive(:open).with("/etc/seth/default.rb").and_yield(@config_file)
        @app.configure_seth
        Seth::Config.rspec_ran.should == "true"
      end

    end

    describe "when there is no config_file defined" do
      before do
        @app.config[:config_file] = nil
      end

      it "should emit a warning" do
        Seth::Config.should_not_receive(:from_file).with("/etc/seth/default.rb")
        Seth::Log.should_receive(:warn).with("No config file found or specified on command line, using command line options.")
        @app.configure_seth
      end
    end

    describe "when the config file is set and not found" do
      before do
        @app.config[:config_file] = "/etc/seth/notfound"
      end
      it "should use the passed in command line options and defaults" do
        Seth::Config.should_receive(:merge!)
        @app.configure_seth
      end
    end
  end

  describe "when configuring the logger" do
    before do
      @app = Seth::Application.new
      Seth::Log.stub(:init)
    end

    it "should initialise the seth logger" do
      Seth::Log.stub(:level=)
      @monologger = double("Monologger")
      MonoLogger.should_receive(:new).with(Seth::Config[:log_location]).and_return(@monologger)
      Seth::Log.should_receive(:init).with(@monologger)
      @app.configure_logging
    end

    it "should raise fatals if log location is invalid" do
      Seth::Config[:log_location] = "/tmp/non-existing-dir/logfile"
      Seth::Log.should_receive(:fatal).at_least(:once)
      Process.should_receive(:exit)
      @app.configure_logging
    end

    shared_examples_for "log_level_is_auto" do
      context "when STDOUT is to a tty" do
        before do
          STDOUT.stub(:tty?).and_return(true)
        end

        it "configures the log level to :warn" do
          @app.configure_logging
          Seth::Log.level.should == :warn
        end

        context "when force_logger is configured" do
          before do
            Seth::Config[:force_logger] = true
          end

          it "configures the log level to info" do
            @app.configure_logging
            Seth::Log.level.should == :info
          end
        end
      end

      context "when STDOUT is not to a tty" do
        before do
          STDOUT.stub(:tty?).and_return(false)
        end

        it "configures the log level to :info" do
          @app.configure_logging
          Seth::Log.level.should == :info
        end

        context "when force_formatter is configured" do
          before do
            Seth::Config[:force_formatter] = true
          end
          it "sets the log level to :warn" do
            @app.configure_logging
            Seth::Log.level.should == :warn
          end
        end
      end
    end

    context "when log_level is not set" do
      it_behaves_like "log_level_is_auto"
    end

    context "when log_level is :auto" do
      before do
        Seth::Config[:log_level] = :auto
      end

      it_behaves_like "log_level_is_auto"
    end
  end

  describe "when configuring environment variables" do
    def configure_proxy_environment_variables_stubs
      @app.stub(:configure_http_proxy).and_return(true)
      @app.stub(:configure_https_proxy).and_return(true)
      @app.stub(:configure_ftp_proxy).and_return(true)
      @app.stub(:configure_no_proxy).and_return(true)
    end

    shared_examples_for "setting ENV['http_proxy']" do
      before do
        Seth::Config[:http_proxy] = http_proxy
      end

      it "should set ENV['http_proxy']" do
        @app.configure_proxy_environment_variables
        @env['http_proxy'].should == "http://#{address}:#{port}"
      end

      describe "when Seth::Config[:http_proxy_user] is set" do
        before do
          Seth::Config[:http_proxy_user] = "username"
        end

        it "should set ENV['http_proxy'] with the username" do
          @app.configure_proxy_environment_variables
          @env['http_proxy'].should == "http://username@#{address}:#{port}"
        end

        context "when :http_proxy_user contains '@' and/or ':'" do
          before do
            Seth::Config[:http_proxy_user] = "my:usern@me"
          end

          it "should set ENV['http_proxy'] with the escaped username" do
            @app.configure_proxy_environment_variables
            @env['http_proxy'].should == "http://my%3Ausern%40me@#{address}:#{port}"
          end
        end

        describe "when Seth::Config[:http_proxy_pass] is set" do
          before do
            Seth::Config[:http_proxy_pass] = "password"
          end

          it "should set ENV['http_proxy'] with the password" do
            @app.configure_proxy_environment_variables
            @env['http_proxy'].should == "http://username:password@#{address}:#{port}"
          end

          context "when :http_proxy_pass contains '@' and/or ':'" do
            before do
              Seth::Config[:http_proxy_pass] = ":P@ssword101"
            end

            it "should set ENV['http_proxy'] with the escaped password" do
              @app.configure_proxy_environment_variables
              @env['http_proxy'].should == "http://username:%3AP%40ssword101@#{address}:#{port}"
            end
          end
        end
      end

      describe "when Seth::Config[:http_proxy_pass] is set (but not seth::Config[:http_proxy_user])" do
        before do
          Seth::Config[:http_proxy_user] = nil
          Seth::Config[:http_proxy_pass] = "password"
        end

        it "should set ENV['http_proxy']" do
          @app.configure_proxy_environment_variables
          @env['http_proxy'].should == "http://#{address}:#{port}"
        end
      end
    end

    describe "when configuring ENV['http_proxy']" do
      before do
        @env = {}
        @app.stub(:env).and_return(@env)

        @app.stub(:configure_https_proxy).and_return(true)
        @app.stub(:configure_ftp_proxy).and_return(true)
        @app.stub(:configure_no_proxy).and_return(true)
      end

      describe "when Seth::Config[:http_proxy] is not set" do
        before do
          Seth::Config[:http_proxy] = nil
        end

        it "should not set ENV['http_proxy']" do
          @app.configure_proxy_environment_variables
          @env.should == {}
        end
      end

      describe "when Seth::Config[:http_proxy] is set" do
        context "when given an FQDN" do
          let(:address) { "proxy.example.org" }
          let(:port) { 8080 }
          let(:http_proxy) { "http://#{address}:#{port}" }

          it_should_behave_like "setting ENV['http_proxy']"
        end

        context "when given an IP" do
          let(:address) { "127.0.0.1" }
          let(:port) { 22 }
          let(:http_proxy) { "http://#{address}:#{port}" }

          it_should_behave_like "setting ENV['http_proxy']"
        end

        context "when given an IPv6" do
          let(:address) { "[2001:db8::1]" }
          let(:port) { 80 }
          let(:http_proxy) { "http://#{address}:#{port}" }

          it_should_behave_like "setting ENV['http_proxy']"
        end

        context "when given without including http://" do
          let(:address) { "proxy.example.org" }
          let(:port) { 8181 }
          let(:http_proxy) { "#{address}:#{port}" }

          it_should_behave_like "setting ENV['http_proxy']"
        end

        context "when given the full proxy in :http_proxy only" do
          before do
            Seth::Config[:http_proxy] = "http://username:password@proxy.example.org:2222"
            Seth::Config[:http_proxy_user] = nil
            Seth::Config[:http_proxy_pass] = nil
          end

          it "should set ENV['http_proxy']" do
            @app.configure_proxy_environment_variables
            @env['http_proxy'].should == Seth::Config[:http_proxy]
          end
        end

        context "when the config options aren't URI compliant" do
          it "raises Seth::Exceptions::BadProxyURI" do
            Seth::Config[:http_proxy] = "http://proxy.bad_example.org/:8080"
            expect { @app.configure_proxy_environment_variables }.to raise_error(Seth::Exceptions::BadProxyURI)
          end
        end
      end
    end
  end

  describe "class method: fatal!" do
    before do
      STDERR.stub(:puts).with("FATAL: blah").and_return(true)
      Seth::Log.stub(:fatal).and_return(true)
      Process.stub(:exit).and_return(true)
    end

    it "should log an error message to the logger" do
      Seth::Log.should_receive(:fatal).with("blah").and_return(true)
      Seth::Application.fatal! "blah"
    end

    describe "when an exit code is supplied" do
      it "should exit with the given exit code" do
        Process.should_receive(:exit).with(-100).and_return(true)
        Seth::Application.fatal! "blah", -100
      end
    end

    describe "when an exit code is not supplied" do
      it "should exit with the default exit code" do
        Process.should_receive(:exit).with(-1).and_return(true)
        Seth::Application.fatal! "blah"
      end
    end

  end

  describe "setup_application" do
    before do
      @app = Seth::Application.new
    end

    it "should raise an error" do
      lambda { @app.setup_application }.should raise_error(Seth::Exceptions::Application)
    end
  end

  describe "run_application" do
    before do
      @app = Seth::Application.new
    end

    it "should raise an error" do
      lambda { @app.run_application }.should raise_error(Seth::Exceptions::Application)
    end
  end

  context "when the config file is not available" do
    it "should warn for bad config file path" do
      @app.config[:config_file] = "/tmp/non-existing-dir/file"
      config_file_regexp = Regexp.new @app.config[:config_file]
      Seth::Log.should_receive(:warn).at_least(:once).with(config_file_regexp).and_return(true)
      Seth::Log.stub(:warn).and_return(true)
      @app.configure_seth
    end
  end

  describe "configuration errors" do
    before do
      Process.should_receive(:exit)
    end

    def raises_informative_fatals_on_configure_seth
      config_file_regexp = Regexp.new @app.config[:config_file]
      Seth::Log.should_receive(:fatal).
        with(/Configuration error/)
      Seth::Log.should_receive(:fatal).
        with(config_file_regexp).
        at_least(1).times
      @app.configure_seth
    end

    describe "when config file exists but contains errors" do
      def create_config_file(text)
        @config_file = Tempfile.new("rspec-seth-config")
        @config_file.write(text)
        @config_file.close
        @app.config[:config_file] = @config_file.path
      end

      after(:each) do
        @config_file.unlink
      end

      it "should raise informative fatals for badly written config" do
        create_config_file("text that should break the config parsing")
        raises_informative_fatals_on_configure_seth
      end
    end
  end
end
