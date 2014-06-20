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
    class RoleEdit < ceth

      deps do
        require 'seth/role'
        require 'seth/json_compat'
      end

      banner "ceth role edit ROLE (options)"

      def run
        @role_name = @name_args[0]

        if @role_name.nil?
          show_usage
          ui.fatal("You must specify a role name")
          exit 1
        end

        ui.edit_object(Seth::Role, @role_name)
      end
    end
  end
end


