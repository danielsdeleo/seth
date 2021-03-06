# Author:: Lamont Granquist (<lamont@opscode.com>)
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


#
# mixin to make this syntax work without specifying a source:
#
# gem_pacakge "/tmp/foo-x.y.z.gem"
# rpm_package "/tmp/foo-x.y-z.rpm"
# dpkg_package "/tmp/foo-x.y.z.deb"
#

class Seth
  module Mixin
    module GetSourceFromPackage
      def initialize(new_resource, run_context)
        super
        # if we're passed something that looks like a filesystem path, with no source, use it
        #  - require at least one '/' in the path to avoid gem_package "foo" breaking if a file named 'foo' exists in the cwd
        if new_resource.source.nil? && new_resource.package_name.match(/#{::File::SEPARATOR}/) && ::File.exists?(new_resource.package_name)
          Seth::Log.debug("No package source specified, but #{new_resource.package_name} exists on the filesystem, copying to package source")
          new_resource.source(@new_resource.package_name)
        end
      end
    end
  end
end

