#
# Author:: AJ Christensen (<aj@opscode.com)
# Author:: Christopher Brown (<cb@opscode.com>)
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

require 'seth/application'
require 'seth/client'
require 'seth/config'
require 'seth/daemon'
require 'seth/log'
require 'seth/config_fetcher'
require 'seth/handler/error_report'

class Seth::Application::Client < Chef::Application

  # Mimic self_pipe sleep from Unicorn to capture signals safely
  SELF_PIPE = []

  option :config_file,
    :short => "-c CONFIG",
    :long  => "--config CONFIG",
    :description => "The configuration file to use"

  option :formatter,
    :short        => "-F FORMATTER",
    :long         => "--format FORMATTER",
    :description  => "output format to use",
    :proc         => lambda { |format| Seth::Config.add_formatter(format) }

  option :force_logger,
    :long         => "--force-logger",
    :description  => "Use logger output instead of formatter output",
    :boolean      => true,
    :default      => false

  option :force_formatter,
    :long         => "--force-formatter",
    :description  => "Use formatter output instead of logger output",
    :boolean      => true,
    :default      => false

  option :color,
    :long         => '--[no-]color',
    :boolean      => true,
    :default      => !Seth::Platform.windows?,
    :description  => "Use colored output, defaults to false on Windows, true otherwise"

  option :log_level,
    :short        => "-l LEVEL",
    :long         => "--log_level LEVEL",
    :description  => "Set the log level (debug, info, warn, error, fatal)",
    :proc         => lambda { |l| l.to_sym }

  option :log_location,
    :short        => "-L LOGLOCATION",
    :long         => "--logfile LOGLOCATION",
    :description  => "Set the log file location, defaults to STDOUT - recommended for daemonizing",
    :proc         => nil

  option :help,
    :short        => "-h",
    :long         => "--help",
    :description  => "Show this message",
    :on           => :tail,
    :boolean      => true,
    :show_options => true,
    :exit         => 0

  option :user,
    :short => "-u USER",
    :long => "--user USER",
    :description => "User to set privilege to",
    :proc => nil

  option :group,
    :short => "-g GROUP",
    :long => "--group GROUP",
    :description => "Group to set privilege to",
    :proc => nil

  unless Seth::Platform.windows?
    option :daemonize,
      :short => "-d",
      :long => "--daemonize",
      :description => "Daemonize the process",
      :proc => lambda { |p| true }
  end

  option :pid_file,
    :short        => "-P PID_FILE",
    :long         => "--pid PIDFILE",
    :description  => "Set the PID file location, defaults to /tmp/seth-client.pid",
    :proc         => nil

  option :interval,
    :short => "-i SECONDS",
    :long => "--interval SECONDS",
    :description => "Run seth-client periodically, in seconds",
    :proc => lambda { |s| s.to_i }

  option :once,
    :long => "--once",
    :description => "Cancel any interval or splay options, run seth once and exit",
    :boolean => true

  option :json_attribs,
    :short => "-j JSON_ATTRIBS",
    :long => "--json-attributes JSON_ATTRIBS",
    :description => "Load attributes from a JSON file or URL",
    :proc => nil

  option :node_name,
    :short => "-N NODE_NAME",
    :long => "--node-name NODE_NAME",
    :description => "The node name for this client",
    :proc => nil

  option :splay,
    :short => "-s SECONDS",
    :long => "--splay SECONDS",
    :description => "The splay time for running at intervals, in seconds",
    :proc => lambda { |s| s.to_i }

  option :seth_server_url,
    :short => "-S CHEFSERVERURL",
    :long => "--server CHEFSERVERURL",
    :description => "The seth server URL",
    :proc => nil

  option :validation_key,
    :short        => "-K KEY_FILE",
    :long         => "--validation_key KEY_FILE",
    :description  => "Set the validation key file location, used for registering new clients",
    :proc         => nil

  option :client_key,
    :short        => "-k KEY_FILE",
    :long         => "--client_key KEY_FILE",
    :description  => "Set the client key file location",
    :proc         => nil

  option :environment,
    :short        => '-E ENVIRONMENT',
    :long         => '--environment ENVIRONMENT',
    :description  => 'Set the Seth Environment on the node'

  option :version,
    :short        => "-v",
    :long         => "--version",
    :description  => "Show seth version",
    :boolean      => true,
    :proc         => lambda {|v| puts "Seth: #{::Chef::VERSION}"},
    :exit         => 0

  option :override_runlist,
    :short        => "-o RunlistItem,RunlistItem...",
    :long         => "--override-runlist RunlistItem,RunlistItem...",
    :description  => "Replace current run list with specified items for a single run",
    :proc         => lambda{|items|
      items = items.split(',')
      items.compact.map{|item|
        Seth::RunList::RunListItem.new(item)
      }
    }

  option :runlist,
    :short        => "-r RunlistItem,RunlistItem...",
    :long         => "--runlist RunlistItem,RunlistItem...",
    :description  => "Permanently replace current run list with specified items",
    :proc         => lambda{|items|
      items = items.split(',')
      items.compact.map{|item|
        Seth::RunList::RunListItem.new(item)
      }
    }
  option :why_run,
    :short        => '-W',
    :long         => '--why-run',
    :description  => 'Enable whyrun mode',
    :boolean      => true

  option :client_fork,
    :short        => "-f",
    :long         => "--[no-]fork",
    :description  => "Fork client",
    :boolean      => true

  option :enable_reporting,
    :short        => "-R",
    :long         => "--enable-reporting",
    :description  => "Enable reporting data collection for seth runs",
    :boolean      => true

  option :local_mode,
    :short        => "-z",
    :long         => "--local-mode",
    :description  => "Point seth-client at local repository",
    :boolean      => true

  option :seth_zero_host,
    :long         => "--seth-zero-host HOST",
    :description  => "Host to start seth-zero on"

  option :seth_zero_port,
    :long         => "--seth-zero-port PORT",
    :description  => "Port to start seth-zero on"

  option :config_file_jail,
    :long         => "--config-file-jail PATH",
    :description  => "Directory under which config files are allowed to be loaded (no client.rb or knife.rb outside this path will be loaded)."

  option :run_lock_timeout,
    :long         => "--run-lock-timeout SECONDS",
    :description  => "Set maximum duration to wait for another client run to finish, default is indefinitely.",
    :proc         => lambda { |s| s.to_i }

  if Seth::Platform.windows?
    option :fatal_windows_admin_check,
      :short        => "-A",
      :long         => "--fatal-windows-admin-check",
      :description  => "Fail the run when seth-client doesn't have administrator privileges on Windows",
      :boolean      => true
  end

  IMMEDIATE_RUN_SIGNAL = "1".freeze
  GRACEFUL_EXIT_SIGNAL = "2".freeze

  attr_reader :seth_client_json

  # Reconfigure the seth client
  # Re-open the JSON attributes and load them into the node
  def reconfigure
    super

    Seth::Config[:specific_recipes] = cli_arguments.map { |file| File.expand_path(file) }

    Seth::Config[:seth_server_url] = config[:chef_server_url] if config.has_key? :chef_server_url

    Seth::Config.local_mode = config[:local_mode] if config.has_key?(:local_mode)
    if Seth::Config.local_mode && !Chef::Config.has_key?(:cookbook_path) && !Chef::Config.has_key?(:seth_repo_path)
      Seth::Config.seth_repo_path = Chef::Config.find_chef_repo_path(Dir.pwd)
    end
    Seth::Config.seth_zero.host = config[:chef_zero_host] if config[:chef_zero_host]
    Seth::Config.seth_zero.port = config[:chef_zero_port] if config[:chef_zero_port]

    if Seth::Config[:daemonize]
      Seth::Config[:interval] ||= 1800
    end

    if Seth::Config[:once]
      Seth::Config[:interval] = nil
      Seth::Config[:splay] = nil
    end

    if Seth::Config[:json_attribs]
      config_fetcher = Seth::ConfigFetcher.new(Chef::Config[:json_attribs])
      @seth_client_json = config_fetcher.fetch_json
    end
  end

  def load_config_file
    Seth::Config.config_file_jail = config[:config_file_jail] if config[:config_file_jail]
    if !config.has_key?(:config_file)
      if config[:local_mode]
        require 'seth/knife'
        config[:config_file] = Seth::Knife.locate_config_file
      else
        config[:config_file] = Seth::Config.platform_specific_path("/etc/seth/client.rb")
      end
    end
    super
  end

  def configure_logging
    super
    Mixlib::Authentication::Log.use_log_devices( Seth::Log )
    Ohai::Log.use_log_devices( Seth::Log )
  end

  def setup_application
    Seth::Daemon.change_privilege
  end

  # Run the seth client, optionally daemonizing or looping at intervals.
  def run_application
    unless Seth::Platform.windows?
      SELF_PIPE.replace IO.pipe

      trap("USR1") do
        Seth::Log.info("SIGUSR1 received, waking up")
        SELF_PIPE[1].putc(IMMEDIATE_RUN_SIGNAL) # wakeup master process from select
      end

      # see CHEF-5172
      if Seth::Config[:daemonize] || Chef::Config[:interval]
        trap("TERM") do
          Seth::Log.info("SIGTERM received, exiting gracefully")
          SELF_PIPE[1].putc(GRACEFUL_EXIT_SIGNAL)
        end
      end
    end

    if Seth::Config[:version]
      puts "Seth version: #{::Chef::VERSION}"
    end

    if Seth::Config[:daemonize]
      Seth::Daemon.daemonize("seth-client")
    end

    signal = nil

    loop do
      begin
        Seth::Application.exit!("Exiting", 0) if signal == GRACEFUL_EXIT_SIGNAL

        if Seth::Config[:splay] and signal != IMMEDIATE_RUN_SIGNAL
          splay = rand Seth::Config[:splay]
          Seth::Log.debug("Splay sleep #{splay} seconds")
          sleep splay
        end

        signal = nil
        run_seth_client(Seth::Config[:specific_recipes])

        if Seth::Config[:interval]
          Seth::Log.debug("Sleeping for #{Chef::Config[:interval]} seconds")
          signal = interval_sleep
        else
          Seth::Application.exit! "Exiting", 0
        end
      rescue SystemExit => e
        raise
      rescue Exception => e
        if Seth::Config[:interval]
          Seth::Log.error("#{e.class}: #{e}")
          Seth::Log.error("Sleeping for #{Chef::Config[:interval]} seconds before trying again")
          signal = interval_sleep
          retry
        else
          Seth::Application.fatal!("#{e.class}: #{e.message}", 1)
        end
      end
    end
  end

  private

  def interval_sleep
    unless SELF_PIPE.empty?
      client_sleep Seth::Config[:interval]
    else
      # Windows
      sleep Seth::Config[:interval]
    end
  end

  def client_sleep(sec)
    IO.select([ SELF_PIPE[0] ], nil, nil, sec) or return
    SELF_PIPE[0].getc.chr
  end
end
