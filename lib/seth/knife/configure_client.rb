#
# Author:: Adam Jacob (<adam@opscode.com>)
# Copyright:: Copyright (c) 2009 Opscode, Inc.
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
  class ceth
    class ConfigureClient < ceth
      banner "ceth configure client DIRECTORY"

      def run
        unless @config_dir = @name_args[0]
          ui.fatal "You must provide the directory to put the files in"
          show_usage
          exit(1)
        end

        ui.info("Creating client configuration")
        FileUtils.mkdir_p(@config_dir)
        ui.info("Writing client.rb")
        File.open(File.join(@config_dir, "client.rb"), "w") do |file|
          file.puts('log_level        :info')
          file.puts('log_location     STDOUT')
          file.puts("seth_server_url  '#{Seth::Config[:seth_server_url]}'")
          file.puts("validation_client_name '#{Seth::Config[:validation_client_name]}'")
        end
        ui.info("Writing validation.pem")
        File.open(File.join(@config_dir, 'validation.pem'), "w") do |validation|
          validation.puts(IO.read(Seth::Config[:validation_key]))
        end
      end

    end
  end
end
