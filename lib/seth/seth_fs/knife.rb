#
# Author:: John Keiser (<jkeiser@opscode.com>)
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

require 'seth/ceth'

class Seth
  module SethFS
    class ceth < Seth::ceth
      # Workaround for seth-3932
      def self.deps
        super do
          require 'seth/config'
          require 'seth/seth_fs/parallelizer'
          require 'seth/seth_fs/config'
          require 'seth/seth_fs/file_pattern'
          require 'seth/seth_fs/path_utils'
          yield
        end
      end

      def self.inherited(c)
        super

        # Ensure we always get to do our includes, whether subclass calls deps or not
        c.deps do
        end

        c.options.merge!(options)
      end

      option :repo_mode,
        :long => '--repo-mode MODE',
        :description => "Specifies the local repository layout.  Values: static, everything, hosted_everything.  Default: everything/hosted_everything"

      option :seth_repo_path,
        :long => '--seth-repo-path PATH',
        :description => 'Overrides the location of seth repo. Default is specified by seth_repo_path in the config'

      option :concurrency,
        :long => '--concurrency THREADS',
        :description => 'Maximum number of simultaneous requests to send (default: 10)'

      def configure_seth
        super
        Seth::Config[:repo_mode] = config[:repo_mode] if config[:repo_mode]
        Seth::Config[:concurrency] = config[:concurrency].to_i if config[:concurrency]

        # --seth-repo-path forcibly overrides all other paths
        if config[:seth_repo_path]
          Seth::Config[:seth_repo_path] = config[:seth_repo_path]
          %w(acl client cookbook container data_bag environment group node role user).each do |variable_name|
            Seth::Config.delete("#{variable_name}_path".to_sym)
          end
        end

        @seth_fs_config = Seth::sethFS::Config.new(seth::Config, Dir.pwd, config)

        Seth::sethFS::Parallelizer.threads = (seth::Config[:concurrency] || 10) - 1
      end

      def seth_fs
        @seth_fs_config.seth_fs
      end

      def create_seth_fs
        @seth_fs_config.create_seth_fs
      end

      def local_fs
        @seth_fs_config.local_fs
      end

      def create_local_fs
        @seth_fs_config.create_local_fs
      end

      def pattern_args
        @pattern_args ||= pattern_args_from(name_args)
      end

      def pattern_args_from(args)
        args.map { |arg| pattern_arg_from(arg) }
      end

      def pattern_arg_from(arg)
        # TODO support absolute file paths and not just patterns?  Too much?
        # Could be super useful in a world with multiple repo paths
        if !@seth_fs_config.base_path && !Seth::sethFS::PathUtils.is_absolute?(arg)
          # Check if seth repo path is specified to give a better error message
          ui.error("Attempt to use relative path '#{arg}' when current directory is outside the repository path")
          exit(1)
        end
        Seth::sethFS::FilePattern.relative_to(@seth_fs_config.base_path, arg)
      end

      def format_path(entry)
        @seth_fs_config.format_path(entry)
      end

      def parallelize(inputs, options = {}, &block)
        Seth::sethFS::Parallelizer.parallelize(inputs, options, &block)
      end

      def discover_repo_dir(dir)
        %w(.seth cookbooks data_bags environments roles).each do |subdir|
          return dir if File.directory?(File.join(dir, subdir))
        end
        # If this isn't it, check the parent
        parent = File.dirname(dir)
        if parent && parent != dir
          discover_repo_dir(parent)
        else
          nil
        end
      end
    end
  end
end
