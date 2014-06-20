require 'spec_helper'

describe Seth::ceth::Configure do
  before do
    Seth::Log.logger = Logger.new(StringIO.new)

    Seth::Config[:node_name]  = "webmonkey.example.com"
    @ceth = Seth::ceth::Configure.new
    @rest_client = double("null rest client", :post_rest => { :result => :true })
    @ceth.stub(:rest).and_return(@rest_client)

    @out = StringIO.new
    @ceth.ui.stub(:stdout).and_return(@out)
    @ceth.config[:config_file] = '/home/you/.seth/ceth.rb'

    @in = StringIO.new("\n" * 7)
    @ceth.ui.stub(:stdin).and_return(@in)

    @err = StringIO.new
    @ceth.ui.stub(:stderr).and_return(@err)

    Ohai::System.stub(:new).and_return(ohai)
  end


  let(:fqdn) { "foo.example.org" }

  let(:ohai) do
    o = {}
    o.stub(:require_plugin)
    o.stub(:load_plugins)
    o[:fqdn] = fqdn
    o
  end

  let(:default_admin_key) { "/etc/seth-server/admin.pem" }
  let(:default_admin_key_win32) { File.expand_path(default_admin_key) }

  let(:default_validator_key) { "/etc/seth-server/seth-validator.pem" }
  let(:default_validator_key_win32) { File.expand_path(default_validator_key) }

  let(:default_server_url) { "https://#{fqdn}:443" }


  it "asks the user for the URL of the seth server" do
    @ceth.ask_user_for_config
    @out.string.should match(Regexp.escape("Please enter the seth server URL: [#{default_server_url}]"))
    @ceth.seth_server.should == default_server_url
  end

  it "asks the user for the clientname they want for the new client if -i is specified" do
    @ceth.config[:initial] = true
    Etc.stub(:getlogin).and_return("a-new-user")
    @ceth.ask_user_for_config
    @out.string.should match(Regexp.escape("Please enter a name for the new user: [a-new-user]"))
    @ceth.new_client_name.should == Etc.getlogin
  end

  it "should not ask the user for the clientname they want for the new client if -i and --node_name are specified" do
    @ceth.config[:initial] = true
    @ceth.config[:node_name] = 'testnode'
    Etc.stub(:getlogin).and_return("a-new-user")
    @ceth.ask_user_for_config
    @out.string.should_not match(Regexp.escape("Please enter a name for the new user"))
    @ceth.new_client_name.should == 'testnode'
  end

  it "asks the user for the existing API username or clientname if -i is not specified" do
    Etc.stub(:getlogin).and_return("a-new-user")
    @ceth.ask_user_for_config
    @out.string.should match(Regexp.escape("Please enter an existing username or clientname for the API: [a-new-user]"))
    @ceth.new_client_name.should == Etc.getlogin
  end

  it "asks the user for the existing admin client's name if -i is specified" do
    @ceth.config[:initial] = true
    @ceth.ask_user_for_config
    @out.string.should match(Regexp.escape("Please enter the existing admin name: [admin]"))
    @ceth.admin_client_name.should == 'admin'
  end

  it "should not ask the user for the existing admin client's name if -i and --admin-client_name are specified" do
    @ceth.config[:initial] = true
    @ceth.config[:admin_client_name] = 'my-webui'
    @ceth.ask_user_for_config
    @out.string.should_not match(Regexp.escape("Please enter the existing admin:"))
    @ceth.admin_client_name.should == 'my-webui'
  end

  it "should not ask the user for the existing admin client's name if -i is not specified" do
    @ceth.ask_user_for_config
    @out.string.should_not match(Regexp.escape("Please enter the existing admin: [admin]"))
    @ceth.admin_client_name.should_not == 'admin'
  end

  it "asks the user for the location of the existing admin key if -i is specified" do
    @ceth.config[:initial] = true
    @ceth.ask_user_for_config
    @out.string.should match(Regexp.escape("Please enter the location of the existing admin's private key: [#{default_admin_key}]"))
    if windows?
      @ceth.admin_client_key.capitalize.should == default_admin_key_win32.capitalize
    else
      @ceth.admin_client_key.should == default_admin_key
    end
  end

  it "should not ask the user for the location of the existing admin key if -i and --admin_client_key are specified" do
    @ceth.config[:initial] = true
    @ceth.config[:admin_client_key] = '/home/you/.seth/my-webui.pem'
    @ceth.ask_user_for_config
    @out.string.should_not match(Regexp.escape("Please enter the location of the existing admin client's private key:"))
    if windows?
      @ceth.admin_client_key.should match %r{^[A-Za-z]:/home/you/\.seth/my-webui\.pem$}
    else
      @ceth.admin_client_key.should == '/home/you/.seth/my-webui.pem'
    end
  end

  it "should not ask the user for the location of the existing admin key if -i is not specified" do
    @ceth.ask_user_for_config
    @out.string.should_not match(Regexp.escape("Please enter the location of the existing admin client's private key: [#{default_admin_key}]"))
    if windows?
      @ceth.admin_client_key.should_not == default_admin_key_win32
    else
      @ceth.admin_client_key.should_not == default_admin_key
    end
  end

  it "asks the user for the location of a seth repo" do
    @ceth.ask_user_for_config
    @out.string.should match(Regexp.escape("Please enter the path to a seth repository (or leave blank):"))
    @ceth.seth_repo.should == ''
  end

  it "asks the users for the name of the validation client" do
    @ceth.ask_user_for_config
    @out.string.should match(Regexp.escape("Please enter the validation clientname: [seth-validator]"))
    @ceth.validation_client_name.should == 'seth-validator'
  end

  it "should not ask the users for the name of the validation client if --validation_client_name is specified" do
    @ceth.config[:validation_client_name] = 'my-validator'
    @ceth.ask_user_for_config
    @out.string.should_not match(Regexp.escape("Please enter the validation clientname:"))
    @ceth.validation_client_name.should == 'my-validator'
  end

  it "asks the users for the location of the validation key" do
    @ceth.ask_user_for_config
    @out.string.should match(Regexp.escape("Please enter the location of the validation key: [#{default_validator_key}]"))
    if windows?
      @ceth.validation_key.capitalize.should == default_validator_key_win32.capitalize
    else
      @ceth.validation_key.should == default_validator_key
    end
  end

  it "should not ask the users for the location of the validation key if --validation_key is specified" do
    @ceth.config[:validation_key] = '/home/you/.seth/my-validation.pem'
    @ceth.ask_user_for_config
    @out.string.should_not match(Regexp.escape("Please enter the location of the validation key:"))
    if windows?
      @ceth.validation_key.should match %r{^[A-Za-z]:/home/you/\.seth/my-validation\.pem$}
    else
      @ceth.validation_key.should == '/home/you/.seth/my-validation.pem'
    end
  end

  it "should not ask the user for anything if -i and all other properties are specified" do
    @ceth.config[:initial] = true
    @ceth.config[:seth_server_url] = 'http://localhost:5000'
    @ceth.config[:node_name] = 'testnode'
    @ceth.config[:admin_client_name] = 'my-webui'
    @ceth.config[:admin_client_key] = '/home/you/.seth/my-webui.pem'
    @ceth.config[:validation_client_name] = 'my-validator'
    @ceth.config[:validation_key] = '/home/you/.seth/my-validation.pem'
    @ceth.config[:repository] = ''
    @ceth.config[:client_key] = '/home/you/a-new-user.pem'
    Etc.stub(:getlogin).and_return('a-new-user')

    @ceth.ask_user_for_config
    @out.string.should match(/\s*/)

    @ceth.new_client_name.should == 'testnode'
    @ceth.seth_server.should == 'http://localhost:5000'
    @ceth.admin_client_name.should == 'my-webui'
    if windows?
      @ceth.admin_client_key.should match %r{^[A-Za-z]:/home/you/\.seth/my-webui\.pem$}
      @ceth.validation_key.should match %r{^[A-Za-z]:/home/you/\.seth/my-validation\.pem$}
      @ceth.new_client_key.should match %r{^[A-Za-z]:/home/you/a-new-user\.pem$}
    else
      @ceth.admin_client_key.should == '/home/you/.seth/my-webui.pem'
      @ceth.validation_key.should == '/home/you/.seth/my-validation.pem'
      @ceth.new_client_key.should == '/home/you/a-new-user.pem'
    end
    @ceth.validation_client_name.should == 'my-validator'
    @ceth.seth_repo.should == ''
  end

  it "writes the new data to a config file" do
    File.stub(:expand_path).with("/home/you/.seth/ceth.rb").and_return("/home/you/.seth/ceth.rb")
    File.stub(:expand_path).with("/home/you/.seth/#{Etc.getlogin}.pem").and_return("/home/you/.seth/#{Etc.getlogin}.pem")
    File.stub(:expand_path).with(default_validator_key).and_return(default_validator_key)
    File.stub(:expand_path).with(default_admin_key).and_return(default_admin_key)
    FileUtils.should_receive(:mkdir_p).with("/home/you/.seth")
    config_file = StringIO.new
    ::File.should_receive(:open).with("/home/you/.seth/ceth.rb", "w").and_yield config_file
    @ceth.config[:repository] = '/home/you/seth-repo'
    @ceth.run
    config_file.string.should match(/^node_name[\s]+'#{Etc.getlogin}'$/)
    config_file.string.should match(%r{^client_key[\s]+'/home/you/.seth/#{Etc.getlogin}.pem'$})
    config_file.string.should match(/^validation_client_name\s+'seth-validator'$/)
    config_file.string.should match(%r{^validation_key\s+'#{default_validator_key}'$})
    config_file.string.should match(%r{^seth_server_url\s+'#{default_server_url}'$})
    config_file.string.should match(%r{cookbook_path\s+\[ '/home/you/seth-repo/cookbooks' \]})
  end

  it "creates a new client when given the --initial option" do
    File.should_receive(:expand_path).with("/home/you/.seth/ceth.rb").and_return("/home/you/.seth/ceth.rb")
    File.should_receive(:expand_path).with("/home/you/.seth/a-new-user.pem").and_return("/home/you/.seth/a-new-user.pem")
    File.should_receive(:expand_path).with(default_validator_key).and_return(default_validator_key)
    File.should_receive(:expand_path).with(default_admin_key).and_return(default_admin_key)
    Seth::Config[:node_name]  = "webmonkey.example.com"

    user_command = Seth::ceth::UserCreate.new
    user_command.should_receive(:run)

    Etc.stub(:getlogin).and_return("a-new-user")

    Seth::ceth::UserCreate.stub(:new).and_return(user_command)
    FileUtils.should_receive(:mkdir_p).with("/home/you/.seth")
    ::File.should_receive(:open).with("/home/you/.seth/ceth.rb", "w")
    @ceth.config[:initial] = true
    @ceth.config[:user_password] = "blah"
    @ceth.run
    user_command.name_args.should == Array("a-new-user")
    user_command.config[:user_password].should == "blah"
    user_command.config[:admin].should be_true
    user_command.config[:file].should == "/home/you/.seth/a-new-user.pem"
    user_command.config[:yes].should be_true
    user_command.config[:disable_editing].should be_true
  end
end
