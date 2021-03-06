#
# Author:: Seth Chisamore (<schisamo@opscode.com>)
# Copyright:: Copyright (c) 2011 Opscode, Inc.
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

require 'seth/file_access_control'

class Seth
  module Mixin
    module EnforceOwnershipAndPermissions

      def access_controls
        @access_controls ||= Seth::FileAccessControl.new(current_resource, new_resource, self)
      end

      # will set the proper user, group and
      # permissions using a platform specific
      # version of Seth::FileAccessControl
      def enforce_ownership_and_permissions
        access_controls.set_all
        new_resource.updated_by_last_action(true) if access_controls.modified?
      end

    end
  end
end
