#
# Author:: Serdar Sutay (<serdar@opscode.com>)
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

require 'seth/deprecation/mixin/template'

class Seth
  module Deprecation
    module Provider

      # == Deprecation::Provider::Template
      # This module contains the deprecated functions of
      # Seth::Provider::Template. These functions are refactored to different
      # components. They are frozen and will be removed in Seth 12.
      #
      module Template

        include Seth::Deprecation::Mixin::Template

        def template_finder
          @template_finder ||= begin
            Seth::Provider::TemplateFinder.new(run_context, cookbook_name, node)
          end
        end

        def template_location
          @template_file_cache_location ||= begin
            template_finder.find(@new_resource.source, :local => @new_resource.local, :cookbook => @new_resource.cookbook)
          end
        end

        def resource_cookbook
          @new_resource.cookbook || @new_resource.cookbook_name
        end

        def rendered(rendered_template)
          @new_resource.checksum(checksum(rendered_template.path))
          Seth::Log.debug("Current content's checksum:  #{@current_resource.checksum}")
          Seth::Log.debug("Rendered content's checksum: #{@new_resource.checksum}")
        end

        def content_matches?
          @current_resource.checksum == @new_resource.checksum
        end

      end
    end
  end
end
