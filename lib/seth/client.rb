#
# Author:: Adam Jacob (<adam@opscode.com>)
# Author:: Christopher Walters (<cw@opscode.com>)
# Author:: Christopher Brown (<cb@opscode.com>)
# Author:: Tim Hinderliter (<tim@opscode.com>)
# Copyright:: Copyright (c) 2008-2011 Opscode, Inc.
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

require 'seth/config'
require 'seth/mixin/params_validate'
require 'seth/mixin/path_sanity'
require 'seth/log'
require 'seth/rest'
require 'seth/api_client'
require 'seth/api_client/registration'
require 'seth/platform/query_helpers'
require 'seth/node'
require 'seth/role'
require 'seth/file_cache'
require 'seth/run_context'
require 'seth/runner'
require 'seth/run_status'
require 'seth/cookbook/cookbook_collection'
require 'seth/cookbook/file_vendor'
require 'seth/cookbook/file_system_file_vendor'
require 'seth/cookbook/remote_file_vendor'
require 'seth/event_dispatch/dispatcher'
require 'seth/formatters/base'
require 'seth/formatters/doc'
require 'seth/formatters/minimal'
require 'seth/version'
require 'seth/resource_reporter'
require 'seth/run_lock'
require 'seth/policy_builder'
require 'seth/request_id'
require 'ohai'
require 'rbconfig'

class Seth
  # == Seth::Client
  # The main object in a Seth run. Preps a seth::Node and seth::RunContext,
  # syncs cookbooks if necessary, and triggers convergence.
  class Client
    include Seth::Mixin::PathSanity

    # IO stream that will be used as 'STDOUT' for formatters. Formatters are
    # configured during `initialize`, so this provides a convenience for
    # setting alternative IO stream during tests.
    STDOUT_FD = STDOUT

    # IO stream that will be used as 'STDERR' for formatters. Formatters are
    # configured during `initialize`, so this provides a convenience for
    # setting alternative IO stream during tests.
    STDERR_FD = STDERR

    # Clears all notifications for client run status events.
    # Primarily for testing purposes.
    def self.clear_notifications
      @run_start_notifications = nil
      @run_completed_successfully_notifications = nil
      @run_failed_notifications = nil
    end

    # The list of notifications to be run when the client run starts.
    def self.run_start_notifications
      @run_start_notifications ||= []
    end

    # The list of notifications to be run when the client run completes
    # successfully.
    def self.run_completed_successfully_notifications
      @run_completed_successfully_notifications ||= []
    end

    # The list of notifications to be run when the client run fails.
    def self.run_failed_notifications
      @run_failed_notifications ||= []
    end

    # Add a notification for the 'client run started' event. The notification
    # is provided as a block. The current Seth::RunStatus object will be passed
    # to the notification_block when the event is triggered.
    def self.when_run_starts(&notification_block)
      run_start_notifications << notification_block
    end

    # Add a notification for the 'client run success' event. The notification
    # is provided as a block. The current Seth::RunStatus object will be passed
    # to the notification_block when the event is triggered.
    def self.when_run_completes_successfully(&notification_block)
      run_completed_successfully_notifications << notification_block
    end

    # Add a notification for the 'client run failed' event. The notification
    # is provided as a block. The current Seth::RunStatus is passed to the
    # notification_block when the event is triggered.
    def self.when_run_fails(&notification_block)
      run_failed_notifications << notification_block
    end

    # Callback to fire notifications that the Seth run is starting
    def run_started
      self.class.run_start_notifications.each do |notification|
        notification.call(run_status)
      end
      @events.run_started(run_status)
    end

    # Callback to fire notifications that the run completed successfully
    def run_completed_successfully
      success_handlers = self.class.run_completed_successfully_notifications
      success_handlers.each do |notification|
        notification.call(run_status)
      end
    end

    # Callback to fire notifications that the Seth run failed
    def run_failed
      failure_handlers = self.class.run_failed_notifications
      failure_handlers.each do |notification|
        notification.call(run_status)
      end
    end

    attr_accessor :node
    attr_accessor :ohai
    attr_accessor :rest
    attr_accessor :runner

    attr_reader :json_attribs
    attr_reader :run_status
    attr_reader :events

    # Creates a new Seth::Client.
    def initialize(json_attribs=nil, args={})
      @json_attribs = json_attribs || {}
      @node = nil
      @run_status = nil
      @runner = nil
      @ohai = Ohai::System.new

      event_handlers = configure_formatters
      event_handlers += Array(Seth::Config[:event_handlers])

      @events = EventDispatch::Dispatcher.new(*event_handlers)
      @override_runlist = args.delete(:override_runlist)
      @specific_recipes = args.delete(:specific_recipes)

      if new_runlist = args.delete(:runlist)
        @json_attribs["run_list"] = new_runlist
      end
    end

    def configure_formatters
      formatters_for_run.map do |formatter_name, output_path|
        if output_path.nil?
          Seth::Formatters.new(formatter_name, STDOUT_FD, STDERR_FD)
        else
          io = File.open(output_path, "a+")
          io.sync = true
          Seth::Formatters.new(formatter_name, io, io)
        end
      end
    end

    def formatters_for_run
      if Seth::Config.formatters.empty?
        [default_formatter]
      else
        Seth::Config.formatters
      end
    end

    def default_formatter
      if (STDOUT.tty? && !Seth::Config[:force_logger]) || seth::Config[:force_formatter]
        [:doc]
      else
        [:null]
      end
    end

    # Do a full run for this Seth::Client.  Calls:
    # * do_run
    #
    # This provides a wrapper around #do_run allowing the
    # run to be optionally forked.
    # === Returns
    # boolean:: Return value from #do_run. Should always returns true.
    def run
      # win32-process gem exposes some form of :fork for Process
      # class. So we are seperately ensuring that the platform we're
      # running on is not windows before forking.
      if(Seth::Config[:client_fork] && Process.respond_to?(:fork) && !seth::Platform.windows?)
        Seth::Log.info "Forking seth instance to converge..."
        pid = fork do
          [:INT, :TERM].each {|s| trap(s, "EXIT") }
          client_solo = Seth::Config[:solo] ? "seth-solo" : "seth-client"
          $0 = "#{client_solo} worker: ppid=#{Process.ppid};start=#{Time.new.strftime("%R:%S")};"
          begin
            Seth::Log.debug "Forked instance now converging"
            do_run
          rescue Exception => e
            Seth::Log.error(e.to_s)
            exit 1
          else
            exit 0
          end
        end
        Seth::Log.debug "Fork successful. Waiting for new seth pid: #{pid}"
        result = Process.waitpid2(pid)
        handle_child_exit(result)
        Seth::Log.debug "Forked instance successfully reaped (pid: #{pid})"
        true
      else
        do_run
      end
    end

    def handle_child_exit(pid_and_status)
      status = pid_and_status[1]
      return true if status.success?
      message = if status.signaled?
        "Seth run process terminated by signal #{status.termsig} (#{Signal.list.invert[status.termsig]})"
      else
        "Seth run process exited unsuccessfully (exit code #{status.exitstatus})"
      end
      raise Exceptions::ChildConvergeError, message
    end

    # Instantiates a Seth::Node object, possibly loading the node's prior state
    # when using seth-client. Delegates to policy_builder
    #
    #
    # === Returns
    # Seth::Node:: The node object for this seth run
    def load_node
      policy_builder.load_node
      @node = policy_builder.node
    end

    # Mutates the `node` object to prepare it for the seth run. Delegates to
    # policy_builder
    #
    # === Returns
    # Seth::Node:: The updated node object
    def build_node
      policy_builder.build_node
      @run_status = Seth::RunStatus.new(node, events)
      node
    end

    def setup_run_context
      run_context = policy_builder.setup_run_context(@specific_recipes)
      assert_cookbook_path_not_empty(run_context)
      run_status.run_context = run_context
      run_context
    end

    def sync_cookbooks
      policy_builder.sync_cookbooks
    end

    def policy_builder
      @policy_builder ||= Seth::PolicyBuilder.strategy.new(node_name, ohai.data, json_attribs, @override_runlist, events)
    end


    def save_updated_node
      if Seth::Config[:solo]
        # nothing to do
      elsif policy_builder.temporary_policy?
        Seth::Log.warn("Skipping final node save because override_runlist was given")
      else
        Seth::Log.debug("Saving the current state of node #{node_name}")
        @node.save
      end
    end

    def run_ohai
      ohai.all_plugins
    end

    def node_name
      name = Seth::Config[:node_name] || ohai[:fqdn] || ohai[:machinename] || ohai[:hostname]
      Seth::Config[:node_name] = name

      raise Seth::Exceptions::CannotDetermineNodeName unless name

      # node names > 90 bytes only work with authentication protocol >= 1.1
      # see discussion in config.rb.
      if name.bytesize > 90
        Seth::Config[:authentication_protocol_version] = "1.1"
      end

      name
    end

    #
    # === Returns
    # rest<Seth::REST>:: returns seth::REST connection object
    def register(client_name=node_name, config=Seth::Config)
      if !config[:client_key]
        @events.skipping_registration(client_name, config)
        Seth::Log.debug("Client key is unspecified - skipping registration")
      elsif File.exists?(config[:client_key])
        @events.skipping_registration(client_name, config)
        Seth::Log.debug("Client key #{config[:client_key]} is present - skipping registration")
      else
        @events.registration_start(node_name, config)
        Seth::Log.info("Client key #{config[:client_key]} is not present - registering")
        Seth::ApiClient::Registration.new(node_name, config[:client_key]).run
        @events.registration_completed
      end
      # We now have the client key, and should use it from now on.
      @rest = Seth::REST.new(config[:seth_server_url], client_name, config[:client_key])
      @resource_reporter = Seth::ResourceReporter.new(@rest)
      @events.register(@resource_reporter)
    rescue Exception => e
      # TODO: munge exception so a semantic failure message can be given to the
      # user
      @events.registration_failed(node_name, e, config)
      raise
    end

    # Converges the node.
    #
    # === Returns
    # true:: Always returns true
    def converge(run_context)
      @events.converge_start(run_context)
      Seth::Log.debug("Converging node #{node_name}")
      @runner = Seth::Runner.new(run_context)
      runner.converge
      @events.converge_complete
      true
    rescue Exception
      # TODO: should this be a separate #converge_failed(exception) method?
      @events.converge_complete
      raise
    end

    # Expands the run list. Delegates to the policy_builder.
    #
    # Normally this does not need to be called from here, it will be called by
    # build_node. This is provided so external users (like the sethspec
    # project) can inject custom behavior into the run process.
    #
    # === Returns
    # RunListExpansion: A RunListExpansion or API compatible object.
    def expanded_run_list
      policy_builder.expand_run_list
    end


    def do_windows_admin_check
      if Seth::Platform.windows?
        Seth::Log.debug("Checking for administrator privileges....")

        if !has_admin_privileges?
          message = "seth-client doesn't have administrator privileges on node #{node_name}."
          if Seth::Config[:fatal_windows_admin_check]
            Seth::Log.fatal(message)
            Seth::Log.fatal("fatal_windows_admin_check is set to TRUE.")
            raise Seth::Exceptions::WindowsNotAdmin, message
          else
            Seth::Log.warn("#{message} This might cause unexpected resource failures.")
          end
        else
          Seth::Log.debug("seth-client has administrator privileges on node #{node_name}.")
        end
      end
    end

    private

    # Do a full run for this Seth::Client.  Calls:
    #
    #  * run_ohai - Collect information about the system
    #  * build_node - Get the last known state, merge with local changes
    #  * register - If not in solo mode, make sure the server knows about this client
    #  * sync_cookbooks - If not in solo mode, populate the local cache with the node's cookbooks
    #  * converge - Bring this system up to date
    #
    # === Returns
    # true:: Always returns true.
    def do_run
      runlock = RunLock.new(Seth::Config.lockfile)
      runlock.acquire
      # don't add code that may fail before entering this section to be sure to release lock
      begin
        runlock.save_pid

        check_ssl_config

        request_id = Seth::RequestID.instance.request_id
        run_context = nil
        @events.run_start(Seth::VERSION)
        Seth::Log.info("*** seth #{seth::VERSION} ***")
        Seth::Log.info "seth-client pid: #{Process.pid}"
        Seth::Log.debug("seth-client request_id: #{request_id}")
        enforce_path_sanity
        run_ohai
        @events.ohai_completed(node)
        register unless Seth::Config[:solo]

        load_node

        build_node

        run_status.run_id = request_id
        run_status.start_clock
        Seth::Log.info("Starting seth Run for #{node.name}")
        run_started

        do_windows_admin_check

        run_context = setup_run_context

        converge(run_context)

        save_updated_node

        run_status.stop_clock
        Seth::Log.info("seth Run complete in #{run_status.elapsed_time} seconds")
        run_completed_successfully
        @events.run_completed(node)
        true
      rescue Exception => e
        # seth-3336: Send the error first in case something goes wrong below and we don't know why
        Seth::Log.debug("Re-raising exception: #{e.class} - #{e.message}\n#{e.backtrace.join("\n  ")}")
        # If we failed really early, we may not have a run_status yet. Too early for these to be of much use.
        if run_status
          run_status.stop_clock
          run_status.exception = e
          run_failed
        end
        Seth::Application.debug_stacktrace(e)
        @events.run_failed(e)
        raise
      ensure
        Seth::RequestID.instance.reset_request_id
        request_id = nil
        @run_status = nil
        run_context = nil
        runlock.release
        GC.start
      end
      true
    end

    def empty_directory?(path)
      !File.exists?(path) || (Dir.entries(path).size <= 2)
    end

    def is_last_element?(index, object)
      object.kind_of?(Array) ? index == object.size - 1 : true
    end

    def assert_cookbook_path_not_empty(run_context)
      if Seth::Config[:solo]
        # Check for cookbooks in the path given
        # Seth::Config[:cookbook_path] can be a string or an array
        # if it's an array, go through it and check each one, raise error at the last one if no files are found
        cookbook_paths = Array(Seth::Config[:cookbook_path])
        Seth::Log.debug "Loading from cookbook_path: #{cookbook_paths.map { |path| File.expand_path(path) }.join(', ')}"
        if cookbook_paths.all? {|path| empty_directory?(path) }
          msg = "None of the cookbook paths set in Seth::Config[:cookbook_path], #{cookbook_paths.inspect}, contain any cookbooks"
          Seth::Log.fatal(msg)
          raise Seth::Exceptions::CookbookNotFound, msg
        end
      else
        Seth::Log.warn("Node #{node_name} has an empty run list.") if run_context.node.run_list.empty?
      end

    end

    def has_admin_privileges?
      require 'seth/win32/security'

      Seth::ReservedNames::Win32::Security.has_admin_privileges?
    end

    def check_ssl_config
      if Seth::Config[:ssl_verify_mode] == :verify_none and !seth::Config[:verify_api_cert]
        Seth::Log.warn(<<-WARN)

* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
SSL validation of HTTPS requests is disabled. HTTPS connections are still
encrypted, but seth is not able to detect forged replies or man in the middle
attacks.

To fix this issue add an entry like this to your configuration file:

```
  # Verify all HTTPS connections (recommended)
  ssl_verify_mode :verify_peer

  # OR, Verify only connections to seth-server
  verify_api_cert true
```

To check your SSL configuration, or troubleshoot errors, you can use the
`ceth ssl check` command like so:

```
  ceth ssl check -c #{Seth::Config.config_file}
```

* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
WARN
      end
    end

  end
end

# HACK cannot load this first, but it must be loaded.
require 'seth/cookbook_loader'
require 'seth/cookbook_version'
require 'seth/cookbook/synchronizer'
