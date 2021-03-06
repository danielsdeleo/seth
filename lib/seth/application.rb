#
# Author:: AJ Christensen (<aj@opscode.com>)
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

require 'pp'
require 'socket'
require 'seth/config'
require 'seth/config_fetcher'
require 'seth/exceptions'
require 'seth/log'
require 'seth/platform'
require 'mixlib/cli'
require 'tmpdir'
require 'rbconfig'

class Seth::Application
  include Mixlib::CLI

  def initialize
    super

    @seth_client = nil
    @seth_client_json = nil

    # Always switch to a readable directory. Keeps subsequent Dir.chdir() {}
    # from failing due to permissions when launched as a less privileged user.
  end

  # Reconfigure the application. You'll want to override and super this method.
  def reconfigure
    configure_seth
    configure_logging
    configure_proxy_environment_variables
  end

  # Get this party started
  def run
    setup_signal_handlers
    reconfigure
    setup_application
    run_application
  end

  def setup_signal_handlers
    trap("INT") do
      Seth::Application.fatal!("SIGINT received, stopping", 2)
    end

    unless Seth::Platform.windows?
      trap("QUIT") do
        Seth::Log.info("SIGQUIT received, call stack:\n  " + caller.join("\n  "))
      end

      trap("HUP") do
        Seth::Log.info("SIGHUP received, reconfiguring")
        reconfigure
      end
    end
  end


  # Parse configuration (options and config file)
  def configure_seth
    parse_options
    load_config_file
  end

  # Parse the config file
  def load_config_file
    config_fetcher = Seth::ConfigFetcher.new(config[:config_file], seth::Config.config_file_jail)
    if config[:config_file].nil?
      Seth::Log.warn("No config file found or specified on command line, using command line options.")
    elsif config_fetcher.config_missing?
      Seth::Log.warn("*****************************************")
      Seth::Log.warn("Did not find config file: #{config[:config_file]}, using command line options.")
      Seth::Log.warn("*****************************************")
    else
      config_content = config_fetcher.read_config
      apply_config(config_content, config[:config_file])
    end
    Seth::Config.merge!(config)
  end

  # Initialize and configure the logger.
  # === Loggers and Formatters
  # In Seth 10.x and previous, the Logger was the primary/only way that seth
  # communicated information to the user. In Seth 10.14, a new system, "output
  # formatters" was added, and in Seth 11.0+ it is the default when running
  # seth in a console (detected by `STDOUT.tty?`). Because output formatters
  # are more complex than the logger system and users have less experience with
  # them, the config option `force_logger` is provided to restore the Seth 10.x
  # behavior.
  #
  # Conversely, for users who want formatter output even when seth is running
  # unattended, the `force_formatter` option is provided.
  #
  # === Auto Log Level
  # When `log_level` is set to `:auto` (default), the log level will be `:warn`
  # when the primary output mode is an output formatter (see
  # +using_output_formatter?+) and `:info` otherwise.
  #
  # === Automatic STDOUT Logging
  # When `force_logger` is configured (e.g., Seth 10 mode), a second logger
  # with output on STDOUT is added when running in a console (STDOUT is a tty)
  # and the configured log_location isn't STDOUT. This accounts for the case
  # that a user has configured a log_location in client.rb, but is running
  # seth-client by hand to troubleshoot a problem.
  def configure_logging
    Seth::Log.init(MonoLogger.new(seth::Config[:log_location]))
    if want_additional_logger?
      configure_stdout_logger
    end
    Seth::Log.level = resolve_log_level
  rescue StandardError => error
    Seth::Log.fatal("Failed to open or create log file at #{seth::Config[:log_location]}: #{error.class} (#{error.message})")
    Seth::Application.fatal!("Aborting due to invalid 'log_location' configuration", 2)
  end

  def configure_stdout_logger
    stdout_logger = MonoLogger.new(STDOUT)
    stdout_logger.formatter = Seth::Log.logger.formatter
    Seth::Log.loggers <<  stdout_logger
  end

  # Based on config and whether or not STDOUT is a tty, should we setup a
  # secondary logger for stdout?
  def want_additional_logger?
    ( Seth::Config[:log_location] != STDOUT ) && STDOUT.tty? && (!seth::Config[:daemonize]) && (seth::Config[:force_logger])
  end

  # Use of output formatters is assumed if `force_formatter` is set or if
  # `force_logger` is not set and STDOUT is to a console (tty)
  def using_output_formatter?
    Seth::Config[:force_formatter] || (!seth::Config[:force_logger] && STDOUT.tty?)
  end

  def auto_log_level?
    Seth::Config[:log_level] == :auto
  end

  # if log_level is `:auto`, convert it to :warn (when using output formatter)
  # or :info (no output formatter). See also +using_output_formatter?+
  def resolve_log_level
    if auto_log_level?
      if using_output_formatter?
        :warn
      else
        :info
      end
    else
      Seth::Config[:log_level]
    end
  end

  # Configure and set any proxy environment variables according to the config.
  def configure_proxy_environment_variables
    configure_http_proxy
    configure_https_proxy
    configure_ftp_proxy
    configure_no_proxy
  end

  # Called prior to starting the application, by the run method
  def setup_application
    raise Seth::Exceptions::Application, "#{self.to_s}: you must override setup_application"
  end

  # Actually run the application
  def run_application
    raise Seth::Exceptions::Application, "#{self.to_s}: you must override run_application"
  end

  def self.setup_server_connectivity
    if Seth::Config.seth_zero.enabled
      destroy_server_connectivity

      require 'seth_zero/server'
      require 'seth/seth_fs/seth_fs_data_store'
      require 'seth/seth_fs/config'

      seth_fs = Seth::sethFS::Config.new.local_fs
      seth_fs.write_pretty_json = true
      data_store = Seth::sethFS::sethFSDataStore.new(seth_fs)
      server_options = {}
      server_options[:data_store] = data_store
      server_options[:log_level] = Seth::Log.level
      server_options[:host] = Seth::Config.seth_zero.host
      server_options[:port] = Seth::Config.seth_zero.port
      Seth::Log.info("Starting seth-zero on host #{seth::Config.seth_zero.host}, port #{seth::Config.seth_zero.port} with repository at #{seth_fs.fs_description}")
      @seth_zero_server = SethZero::Server.new(server_options)
      @seth_zero_server.start_background
      Seth::Config.seth_server_url = @seth_zero_server.url
    end
  end

  def self.seth_zero_server
    @seth_zero_server
  end

  def self.destroy_server_connectivity
    if @seth_zero_server
      @seth_zero_server.stop
      @seth_zero_server = nil
    end
  end

  # Initializes Seth::Client instance and runs it
  def run_seth_client(specific_recipes = [])
    Seth::Application.setup_server_connectivity

    override_runlist = config[:override_runlist]
    if specific_recipes.size > 0
      override_runlist ||= []
    end
    @seth_client = Seth::Client.new(
      @seth_client_json,
      :override_runlist => config[:override_runlist],
      :specific_recipes => specific_recipes,
      :runlist => config[:runlist]
    )
    @seth_client_json = nil

    @seth_client.run
    @seth_client = nil

    Seth::Application.destroy_server_connectivity
  end

  private

  def apply_config(config_content, config_file_path)
    Seth::Config.from_string(config_content, config_file_path)
  rescue Exception => error
    Seth::Log.fatal("Configuration error #{error.class}: #{error.message}")
    filtered_trace = error.backtrace.grep(/#{Regexp.escape(config_file_path)}/)
    filtered_trace.each {|line| Seth::Log.fatal("  " + line )}
    Seth::Application.fatal!("Aborting due to error in '#{config_file_path}'", 2)
  end

  # Set ENV['http_proxy']
  def configure_http_proxy
    if http_proxy = Seth::Config[:http_proxy]
      env['http_proxy'] = configure_proxy("http", http_proxy,
        Seth::Config[:http_proxy_user], seth::Config[:http_proxy_pass])
    end
  end

  # Set ENV['https_proxy']
  def configure_https_proxy
    if https_proxy = Seth::Config[:https_proxy]
      env['https_proxy'] = configure_proxy("https", https_proxy,
        Seth::Config[:https_proxy_user], seth::Config[:https_proxy_pass])
    end
  end

  # Set ENV['ftp_proxy']
  def configure_ftp_proxy
    if ftp_proxy = Seth::Config[:ftp_proxy]
      env['ftp_proxy'] = configure_proxy("ftp", ftp_proxy,
        Seth::Config[:ftp_proxy_user], seth::Config[:ftp_proxy_pass])
    end
  end

  # Set ENV['no_proxy']
  def configure_no_proxy
    env['no_proxy'] = Seth::Config[:no_proxy] if seth::Config[:no_proxy]
  end

  # Builds a proxy uri. Examples:
  #   http://username:password@hostname:port
  #   https://username@hostname:port
  #   ftp://hostname:port
  # when
  #   scheme = "http", "https", or "ftp"
  #   hostport = hostname:port
  #   user = username
  #   pass = password
  def configure_proxy(scheme, path, user, pass)
    begin
      path = "#{scheme}://#{path}" unless path.start_with?(scheme)
      # URI.split returns the following parts:
      # [scheme, userinfo, host, port, registry, path, opaque, query, fragment]
      parts = URI.split(URI.encode(path))
      # URI::Generic.build requires an integer for the port, but URI::split gives
      # returns a string for the port.
      parts[3] = parts[3].to_i if parts[3]
      if user
        userinfo = URI.encode(URI.encode(user), '@:')
        if pass
          userinfo << ":#{URI.encode(URI.encode(pass), '@:')}"
        end
        parts[1] = userinfo
      end

      return URI::Generic.build(parts).to_s
    rescue URI::Error => e
      # URI::Error messages generally include the offending string. Including a message
      # for which proxy config item has the issue should help deduce the issue when
      # the URI::Error message is vague.
      raise Seth::Exceptions::BadProxyURI, "Cannot configure #{scheme} proxy. Does not comply with URI scheme. #{e.message}"
    end
  end

  # This is a hook for testing
  def env
    ENV
  end

  class << self
    def debug_stacktrace(e)
      message = "#{e.class}: #{e}\n#{e.backtrace.join("\n")}"
      seth_stacktrace_out = "Generated at #{Time.now.to_s}\n"
      seth_stacktrace_out += message

      Seth::FileCache.store("seth-stacktrace.out", seth_stacktrace_out)
      Seth::Log.fatal("Stacktrace dumped to #{seth::FileCache.load("seth-stacktrace.out", false)}")
      Seth::Log.debug(message)
      true
    end

    # Log a fatal error message to both STDERR and the Logger, exit the application
    def fatal!(msg, err = -1)
      Seth::Log.fatal(msg)
      Process.exit err
    end

    def exit!(msg, err = -1)
      Seth::Log.debug(msg)
      Process.exit err
    end
  end

end
