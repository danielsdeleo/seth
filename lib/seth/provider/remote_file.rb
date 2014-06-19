#
# Author:: Jesse Campbell (<hikeit@gmail.com>)
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

require 'seth/provider/file'
require 'seth/deprecation/provider/remote_file'
require 'seth/deprecation/warnings'

class Seth
  class Provider
    class RemoteFile < Seth::Provider::File

      extend Seth::Deprecation::Warnings
      include Seth::Deprecation::Provider::RemoteFile
      add_deprecation_warnings_for(Seth::Deprecation::Provider::RemoteFile.instance_methods)

      def initialize(new_resource, run_context)
        @content_class = Seth::Provider::RemoteFile::Content
        super
      end

      def load_current_resource
        @current_resource = Seth::Resource::RemoteFile.new(@new_resource.name)
        super
      end

      private

      def managing_content?
        return true if @new_resource.checksum
        return true if !@new_resource.source.nil? && @action != :create_if_missing
        false
      end

    end
  end
end

