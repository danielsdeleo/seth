#
# Author:: Lamont Granquist (<lamont@opscode.com>)
# Copyright:: Copyright (c) 2013 Opscode, Inc.
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

require 'seth/file_content_management/content_base'
require 'seth/file_content_management/tempfile'

class Seth
  class Provider
    class File
      class Content < Seth::FileContentManagement::ContentBase
        def file_for_provider
          if @new_resource.content
            tempfile = Seth::FileContentManagement::Tempfile.new(@new_resource).tempfile
            tempfile.write(@new_resource.content)
            tempfile.close
            tempfile
          else
            nil
          end
        end
      end
    end
  end
end
