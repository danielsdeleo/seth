#
# Author:: Adam Jacob (<adam@opscode.com>)
# Author:: Tim Hinderliter (<tim@opscode.com>)
# Copyright:: Copyright (c) 2008, 2011 Opscode, Inc.
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

# Fixtures for subcommand loading live in this namespace
module cethSpecs
end

require 'spec_helper'
require 'uri'

describe Seth::ceth do
  before(:each) do
    Seth::Log.logger = Logger.new(StringIO.new)

    Seth::Config[:node_name]  = "webmonkey.example.com"

    # Prevent gratuitous code reloading:
    Seth::ceth.stub(:load_commands)
    @ceth = Seth::ceth.new
    @ceth.ui.stub(:puts)
    @ceth.ui.stub(:print)
    Seth::Log.stub(:init)
    Seth::Log.stub(:level)
    [:debug, :info, :warn, :error, :crit].each do |level_sym|
      Seth::Log.stub(level_sym)
    end
    Seth::ceth.stub(:puts)
    @stdout = StringIO.new
  end

  describe "selecting a config file" do
    context "when the current working dir is inside a symlinked directory" do
      before do
        Seth::ceth.reset_config_path!
        # pwd according to your shell is /home/someuser/prod/seth-repo, but
        # seth-repo is a symlink to /home/someuser/codes/seth-repo
        if Seth::Platform.windows?
          ENV.should_receive(:[]).with("CD").and_return("/home/someuser/prod/seth-repo")
        else
          ENV.should_receive(:[]).with("PWD").and_return("/home/someuser/prod/seth-repo")
        end

        Dir.stub(:pwd).and_return("/home/someuser/codes/seth-repo")
      end

      after do
        Seth::ceth.reset_config_path!
      end

      it "loads the config from the non-dereferenced directory path" do
        File.should_receive(:exist?).with("/home/someuser/prod/seth-repo/.seth").and_return(false)
        File.should_receive(:exist?).with("/home/someuser/prod/.seth").and_return(true)
        File.should_receive(:directory?).with("/home/someuser/prod/.seth").and_return(true)
        Seth::ceth.seth_config_dir.should == "/home/someuser/prod/.seth"
      end
    end
  end

  describe "after loading a subcommand" do
    before do
      Seth::ceth.reset_subcommands!

      if cethSpecs.const_defined?(:TestNameMapping)
        cethSpecs.send(:remove_const, :TestNameMapping)
      end

      if cethSpecs.const_defined?(:TestExplicitCategory)
        cethSpecs.send(:remove_const, :TestExplicitCategory)
      end

      Kernel.load(File.join(seth_SPEC_DATA, 'ceth_subcommand', 'test_name_mapping.rb'))
      Kernel.load(File.join(seth_SPEC_DATA, 'ceth_subcommand', 'test_explicit_category.rb'))
    end

    it "has a category based on its name" do
      cethSpecs::TestNameMapping.subcommand_category.should == 'test'
    end

    it "has an explictly defined category if set" do
      cethSpecs::TestExplicitCategory.subcommand_category.should == 'cookbook site'
    end

    it "can reference the subcommand by its snake cased name" do
      Seth::ceth.subcommands['test_name_mapping'].should equal(cethSpecs::TestNameMapping)
    end

    it "lists subcommands by category" do
      Seth::ceth.subcommands_by_category['test'].should include('test_name_mapping')
    end

    it "lists subcommands by category when the subcommands have explicit categories" do
      Seth::ceth.subcommands_by_category['cookbook site'].should include('test_explicit_category')
    end

    it "has empty dependency_loader list by default" do
      cethSpecs::TestNameMapping.dependency_loaders.should be_empty
    end
  end

  describe "after loading all subcommands" do
    before do
      Seth::ceth.reset_subcommands!
      Seth::ceth.load_commands
    end

    it "references a subcommand class by its snake cased name" do
      class SuperAwesomeCommand < Seth::ceth
      end

      Seth::ceth.load_commands

      Seth::ceth.subcommands.should have_key("super_awesome_command")
      Seth::ceth.subcommands["super_awesome_command"].should == SuperAwesomeCommand
    end

    it "guesses a category from a given ARGV" do
      Seth::ceth.subcommands_by_category["cookbook"] << :cookbook
      Seth::ceth.subcommands_by_category["cookbook site"] << :cookbook_site
      Seth::ceth.guess_category(%w{cookbook foo bar baz}).should == 'cookbook'
      Seth::ceth.guess_category(%w{cookbook site foo bar baz}).should == 'cookbook site'
      Seth::ceth.guess_category(%w{cookbook site --help}).should == 'cookbook site'
    end

    it "finds a subcommand class based on ARGV" do
      Seth::ceth.subcommands["cookbook_site_vendor"] = :CookbookSiteVendor
      Seth::ceth.subcommands["cookbook"] = :Cookbook
      Seth::ceth.subcommand_class_from(%w{cookbook site vendor --help foo bar baz}).should == :CookbookSiteVendor
    end

  end

  describe "the headers include X-Remote-Request-Id" do

    let(:headers) {{"Accept"=>"application/json",
                    "Accept-Encoding"=>"gzip;q=1.0,deflate;q=0.6,identity;q=0.3",
                    'X-Seth-Version' => seth::VERSION,
                    "Host"=>"api.opscode.piab",
                    "X-REMOTE-REQUEST-ID"=>request_id}}

    let(:request_id) {"1234"}

    let(:request_mock) { {} }

    let(:rest) do
      Net::HTTP.stub(:new).and_return(http_client)
      Seth::RequestID.instance.stub(:request_id).and_return(request_id)
      Seth::Config.stub(:seth_server_url).and_return("https://api.opscode.piab")
      command = Seth::ceth.run(%w{test yourself})
      rest = command.noauth_rest
      rest
    end

    let!(:http_client) do
      http_client = Net::HTTP.new(url.host, url.port)
      http_client.stub(:request).and_yield(http_response).and_return(http_response)
      http_client
    end

    let(:url) { URI.parse("https://api.opscode.piab") }

    let(:http_response) do
      http_response = Net::HTTPSuccess.new("1.1", "200", "successful rest req")
      http_response.stub(:read_body)
      http_response.stub(:body).and_return(body)
      http_response["Content-Length"] = body.bytesize.to_s
      http_response
    end

    let(:body) { "ninja" }

    before(:each) do
      Seth::Config[:seth_server_url] = "https://api.opscode.piab"
      if cethSpecs.const_defined?(:TestYourself)
        cethSpecs.send :remove_const, :TestYourself
      end
      Kernel.load(File.join(seth_SPEC_DATA, 'ceth_subcommand', 'test_yourself.rb'))
      Seth::ceth.subcommands.each { |name, klass| seth::ceth.subcommands.delete(name) unless klass.kind_of?(Class) }
    end

    it "confirms that the headers include X-Remote-Request-Id" do
      Net::HTTP::Get.should_receive(:new).with("/monkey", headers).and_return(request_mock)
      rest.get_rest("monkey")
    end
  end

  describe "when running a command" do
    before(:each) do
      if cethSpecs.const_defined?(:TestYourself)
        cethSpecs.send :remove_const, :TestYourself
      end
      Kernel.load(File.join(seth_SPEC_DATA, 'ceth_subcommand', 'test_yourself.rb'))
      Seth::ceth.subcommands.each { |name, klass| seth::ceth.subcommands.delete(name) unless klass.kind_of?(Class) }
    end

    it "merges the global ceth CLI options" do
      extra_opts = {}
      extra_opts[:editor] = {:long=>"--editor EDITOR",
                             :description=>"Set the editor to use for interactive commands",
                             :short=>"-e EDITOR",
                             :default=>"/usr/bin/vim"}

      # there is special hackery to return the subcommand instance going on here.
      command = Seth::ceth.run(%w{test yourself}, extra_opts)
      editor_opts = command.options[:editor]
      editor_opts[:long].should         == "--editor EDITOR"
      editor_opts[:description].should  == "Set the editor to use for interactive commands"
      editor_opts[:short].should        == "-e EDITOR"
      editor_opts[:default].should      == "/usr/bin/vim"
    end

    it "creates an instance of the subcommand and runs it" do
      command = Seth::ceth.run(%w{test yourself})
      command.should be_an_instance_of(cethSpecs::TestYourself)
      command.ran.should be_true
    end

    it "passes the command specific args to the subcommand" do
      command = Seth::ceth.run(%w{test yourself with some args})
      command.name_args.should == %w{with some args}
    end

    it "excludes the command name from the name args when parts are joined with underscores" do
      command = Seth::ceth.run(%w{test_yourself with some args})
      command.name_args.should == %w{with some args}
    end

    it "exits if no subcommand matches the CLI args" do
      Seth::ceth.ui.stub(:stdout).and_return(@stdout)
      Seth::ceth.ui.should_receive(:fatal)
      lambda {Seth::ceth.run(%w{fuuu uuuu fuuuu})}.should raise_error(SystemExit) { |e| e.status.should_not == 0 }
    end

    it "loads lazy dependencies" do
      command = Seth::ceth.run(%w{test yourself})
      cethSpecs::TestYourself.test_deps_loaded.should be_true
    end

    it "loads lazy dependencies from multiple deps calls" do
      other_deps_loaded = false
      cethSpecs::TestYourself.class_eval do
        deps { other_deps_loaded = true }
      end
      command = Seth::ceth.run(%w{test yourself})
      cethSpecs::TestYourself.test_deps_loaded.should be_true
      other_deps_loaded.should be_true
    end

    describe "merging configuration options" do
      before do
        cethSpecs::TestYourself.option(:opt_with_default,
                                        :short => "-D VALUE",
                                        :default => "default-value")
      end

      it "prefers the default value if no config or command line value is present" do
        ceth_command = cethSpecs::TestYourself.new([]) #empty argv
        ceth_command.configure_seth
        ceth_command.config[:opt_with_default].should == "default-value"
      end

      it "prefers a value in Seth::Config[:ceth] to the default" do
        Seth::Config[:ceth][:opt_with_default] = "from-ceth-config"
        ceth_command = cethSpecs::TestYourself.new([]) #empty argv
        ceth_command.configure_seth
        ceth_command.config[:opt_with_default].should == "from-ceth-config"
      end

      it "prefers a value from command line over Seth::Config and the default" do
        Seth::Config[:ceth][:opt_with_default] = "from-ceth-config"
        ceth_command = cethSpecs::TestYourself.new(["-D", "from-cli"])
        ceth_command.configure_seth
        ceth_command.config[:opt_with_default].should == "from-cli"
      end
    end

  end

  describe "when first created" do
    before do
      unless cethSpecs.const_defined?(:TestYourself)
        Kernel.load(File.join(seth_SPEC_DATA, 'ceth_subcommand', 'test_yourself.rb'))
      end
      @ceth = cethSpecs::TestYourself.new(%w{with some args -s scrogramming})
    end

    it "it parses the options passed to it" do
      @ceth.config[:scro].should == 'scrogramming'
    end

    it "extracts its command specific args from the full arg list" do
      @ceth.name_args.should == %w{with some args}
    end

    it "does not have lazy dependencies loaded" do
      @ceth.class.test_deps_loaded.should_not be_true
    end
  end

  describe "when formatting exceptions" do
    before do
      @stdout, @stderr, @stdin = StringIO.new, StringIO.new, StringIO.new
      @ceth.ui = Seth::ceth::UI.new(@stdout, @stderr, @stdin, {})
      @ceth.should_receive(:exit).with(100)
    end

    it "formats 401s nicely" do
      response = Net::HTTPUnauthorized.new("1.1", "401", "Unauthorized")
      response.instance_variable_set(:@read, true) # I hate you, net/http.
      response.stub(:body).and_return(Seth::JSONCompat.to_json(:error => "y u no syncronize your clock?"))
      @ceth.stub(:run).and_raise(Net::HTTPServerException.new("401 Unauthorized", response))
      @ceth.run_with_pretty_exceptions
      @stderr.string.should match(/ERROR: Failed to authenticate to/)
      @stdout.string.should match(/Response:  y u no syncronize your clock\?/)
    end

    it "formats 403s nicely" do
      response = Net::HTTPForbidden.new("1.1", "403", "Forbidden")
      response.instance_variable_set(:@read, true) # I hate you, net/http.
      response.stub(:body).and_return(Seth::JSONCompat.to_json(:error => "y u no administrator"))
      @ceth.stub(:run).and_raise(Net::HTTPServerException.new("403 Forbidden", response))
      @ceth.stub(:username).and_return("sadpanda")
      @ceth.run_with_pretty_exceptions
      @stderr.string.should match(%r[ERROR: You authenticated successfully to http.+ as sadpanda but you are not authorized for this action])
      @stdout.string.should match(%r[Response:  y u no administrator])
    end

    it "formats 400s nicely" do
      response = Net::HTTPBadRequest.new("1.1", "400", "Bad Request")
      response.instance_variable_set(:@read, true) # I hate you, net/http.
      response.stub(:body).and_return(Seth::JSONCompat.to_json(:error => "y u search wrong"))
      @ceth.stub(:run).and_raise(Net::HTTPServerException.new("400 Bad Request", response))
      @ceth.run_with_pretty_exceptions
      @stderr.string.should match(%r[ERROR: The data in your request was invalid])
      @stdout.string.should match(%r[Response: y u search wrong])
    end

    it "formats 404s nicely" do
      response = Net::HTTPNotFound.new("1.1", "404", "Not Found")
      response.instance_variable_set(:@read, true) # I hate you, net/http.
      response.stub(:body).and_return(Seth::JSONCompat.to_json(:error => "nothing to see here"))
      @ceth.stub(:run).and_raise(Net::HTTPServerException.new("404 Not Found", response))
      @ceth.run_with_pretty_exceptions
      @stderr.string.should match(%r[ERROR: The object you are looking for could not be found])
      @stdout.string.should match(%r[Response: nothing to see here])
    end

    it "formats 500s nicely" do
      response = Net::HTTPInternalServerError.new("1.1", "500", "Internal Server Error")
      response.instance_variable_set(:@read, true) # I hate you, net/http.
      response.stub(:body).and_return(Seth::JSONCompat.to_json(:error => "sad trombone"))
      @ceth.stub(:run).and_raise(Net::HTTPFatalError.new("500 Internal Server Error", response))
      @ceth.run_with_pretty_exceptions
      @stderr.string.should match(%r[ERROR: internal server error])
      @stdout.string.should match(%r[Response: sad trombone])
    end

    it "formats 502s nicely" do
      response = Net::HTTPBadGateway.new("1.1", "502", "Bad Gateway")
      response.instance_variable_set(:@read, true) # I hate you, net/http.
      response.stub(:body).and_return(Seth::JSONCompat.to_json(:error => "sadder trombone"))
      @ceth.stub(:run).and_raise(Net::HTTPFatalError.new("502 Bad Gateway", response))
      @ceth.run_with_pretty_exceptions
      @stderr.string.should match(%r[ERROR: bad gateway])
      @stdout.string.should match(%r[Response: sadder trombone])
    end

    it "formats 503s nicely" do
      response = Net::HTTPServiceUnavailable.new("1.1", "503", "Service Unavailable")
      response.instance_variable_set(:@read, true) # I hate you, net/http.
      response.stub(:body).and_return(Seth::JSONCompat.to_json(:error => "saddest trombone"))
      @ceth.stub(:run).and_raise(Net::HTTPFatalError.new("503 Service Unavailable", response))
      @ceth.run_with_pretty_exceptions
      @stderr.string.should match(%r[ERROR: Service temporarily unavailable])
      @stdout.string.should match(%r[Response: saddest trombone])
    end

    it "formats other HTTP errors nicely" do
      response = Net::HTTPPaymentRequired.new("1.1", "402", "Payment Required")
      response.instance_variable_set(:@read, true) # I hate you, net/http.
      response.stub(:body).and_return(Seth::JSONCompat.to_json(:error => "nobugfixtillyoubuy"))
      @ceth.stub(:run).and_raise(Net::HTTPServerException.new("402 Payment Required", response))
      @ceth.run_with_pretty_exceptions
      @stderr.string.should match(%r[ERROR: Payment Required])
      @stdout.string.should match(%r[Response: nobugfixtillyoubuy])
    end

    it "formats NameError and NoMethodError nicely" do
      @ceth.stub(:run).and_raise(NameError.new("Undefined constant FUUU"))
      @ceth.run_with_pretty_exceptions
      @stderr.string.should match(%r[ERROR: ceth encountered an unexpected error])
      @stdout.string.should match(%r[This may be a bug in the 'ceth' ceth command or plugin])
      @stdout.string.should match(%r[Exception: NameError: Undefined constant FUUU])
    end

    it "formats missing private key errors nicely" do
      @ceth.stub(:run).and_raise(Seth::Exceptions::PrivateKeyMissing.new('key not there'))
      @ceth.stub(:api_key).and_return("/home/root/.seth/no-key-here.pem")
      @ceth.run_with_pretty_exceptions
      @stderr.string.should match(%r[ERROR: Your private key could not be loaded from /home/root/.seth/no-key-here.pem])
      @stdout.string.should match(%r[Check your configuration file and ensure that your private key is readable])
    end

    it "formats connection refused errors nicely" do
      @ceth.stub(:run).and_raise(Errno::ECONNREFUSED.new('y u no shut up'))
      @ceth.run_with_pretty_exceptions
      # Errno::ECONNREFUSED message differs by platform
      # *nix = Errno::ECONNREFUSED: Connection refused
      # win32: Errno::ECONNREFUSED: No connection could be made because the target machine actively refused it.
      @stderr.string.should match(%r[ERROR: Network Error: .* - y u no shut up])
      @stdout.string.should match(%r[Check your ceth configuration and network settings])
    end
  end

end
