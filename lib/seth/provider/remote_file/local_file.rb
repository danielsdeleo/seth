#
# Author:: Jesse Campbell (<hikeit@gmail.com>)
# Copyright:: Copyright (c) 2013 Jesse Campbell
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

require 'uri'
require 'tempfile'
require 'seth/provider/remote_file'

class Seth
  class Provider
    class RemoteFile
      class LocalFile

        attr_reader :uri
        attr_reader :new_resource

        def initialize(uri, new_resource, current_resource)
          @new_resource = new_resource
          @uri = uri
        end

        # seth-4472: Remove the leading slash from windows paths that we receive from a file:// URI
        def fix_windows_path(path)
          path.gsub(/^\/([a-zA-Z]:)/,'\1')
        end

        # Fetches the file at uri, returning a Tempfile-like File handle
        def fetch
          source_path = Seth::Platform.windows? ? fix_windows_path(uri.path) : uri.path
          tempfile = Seth::FileContentManagement::Tempfile.new(new_resource).tempfile
          Seth::Log.debug("#{new_resource} staging #{source_path} to #{tempfile.path}")
          FileUtils.cp(source_path, tempfile.path)
          tempfile.close if tempfile
          tempfile
        end

      end
    end
  end
end
