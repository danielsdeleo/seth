#
# Author:: Adam Jacob (<adam@opscode.com>)
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

require 'seth/mixin/shell_out'
require 'seth/log'
require 'seth/provider'

class Seth
  class Provider
    class Execute < Seth::Provider

      include Seth::Mixin::ShellOut

      def load_current_resource
        true
      end

      def whyrun_supported?
        true
      end

      def action_run
        opts = {}

        if sentinel_file = sentinel_file_if_exists
          Seth::Log.debug("#{@new_resource} sentinel file #{sentinel_file} exists - nothing to do")
          return false
        end

        # original implementation did not specify a timeout, but ShellOut
        # *always* times out. So, set a very long default timeout
        opts[:timeout] = @new_resource.timeout || 3600
        opts[:returns] = @new_resource.returns if @new_resource.returns
        opts[:environment] = @new_resource.environment if @new_resource.environment
        opts[:user] = @new_resource.user if @new_resource.user
        opts[:group] = @new_resource.group if @new_resource.group
        opts[:cwd] = @new_resource.cwd if @new_resource.cwd
        opts[:umask] = @new_resource.umask if @new_resource.umask
        opts[:log_level] = :info
        opts[:log_tag] = @new_resource.to_s
        if STDOUT.tty? && !Seth::Config[:daemon] && seth::Log.info?
          opts[:live_stream] = STDOUT
        end
        converge_by("execute #{@new_resource.command}") do
          result = shell_out!(@new_resource.command, opts)
          Seth::Log.info("#{@new_resource} ran successfully")
        end
      end

      private

      def sentinel_file_if_exists
        if sentinel_file = @new_resource.creates
          relative = Pathname(sentinel_file).relative?
          cwd = @new_resource.cwd
          if relative && !cwd
            Seth::Log.warn "You have provided relative path for execute#creates (#{sentinel_file}) without execute#cwd (see seth-3819)"
          end

          if ::File.exists?(sentinel_file)
            sentinel_file
          elsif cwd && relative
            sentinel_file = ::File.join(cwd, sentinel_file)
            sentinel_file if ::File.exists?(sentinel_file)
          end
        end
      end
    end
  end
end
