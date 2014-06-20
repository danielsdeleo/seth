#
# Author:: Jan Zimmek (<jan.zimmek@web.de>)
# Copyright:: Copyright (c) 2010 Jan Zimmek
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

require 'seth/provider/package'
require 'seth/mixin/command'
require 'seth/resource/package'

class Seth
  class Provider
    class Package
      class Pacman < Seth::Provider::Package

        def load_current_resource
          @current_resource = Seth::Resource::Package.new(@new_resource.name)
          @current_resource.package_name(@new_resource.package_name)

          @current_resource.version(nil)

          Seth::Log.debug("#{@new_resource} checking pacman for #{@new_resource.package_name}")
          status = popen4("pacman -Qi #{@new_resource.package_name}") do |pid, stdin, stdout, stderr|
            stdout.each do |line|
              line.force_encoding(Encoding::UTF_8) if line.respond_to?(:force_encoding)
              case line
              when /^Version(\s?)*: (.+)$/
                Seth::Log.debug("#{@new_resource} current version is #{$2}")
                @current_resource.version($2)
              end
            end
          end

          unless status.exitstatus == 0 || status.exitstatus == 1
            raise Seth::Exceptions::Package, "pacman failed - #{status.inspect}!"
          end

          @current_resource
        end

        def candidate_version
          return @candidate_version if @candidate_version

          repos = ["extra","core","community"]

          if(::File.exists?("/etc/pacman.conf"))
            pacman = ::File.read("/etc/pacman.conf")
            repos = pacman.scan(/\[(.+)\]/).flatten
          end

          package_repos = repos.map {|r| Regexp.escape(r) }.join('|')

          status = popen4("pacman -Ss #{@new_resource.package_name}") do |pid, stdin, stdout, stderr|
            stdout.each do |line|
              case line
                when /^(#{package_repos})\/#{Regexp.escape(@new_resource.package_name)} (.+)$/
                  # $2 contains a string like "4.4.0-1 (kde kdenetwork)" or "3.10-4 (base)"
                  # simply split by space and use first token
                  @candidate_version = $2.split(" ").first
              end
            end
          end

          unless status.exitstatus == 0 || status.exitstatus == 1
            raise Seth::Exceptions::Package, "pacman failed - #{status.inspect}!"
          end

          unless @candidate_version
            raise Seth::Exceptions::Package, "pacman does not have a version of package #{@new_resource.package_name}"
          end

          @candidate_version

        end

        def install_package(name, version)
          run_command_with_systems_locale(
            :command => "pacman --sync --noconfirm --noprogressbar#{expand_options(@new_resource.options)} #{name}"
          )
        end

        def upgrade_package(name, version)
          install_package(name, version)
        end

        def remove_package(name, version)
          run_command_with_systems_locale(
            :command => "pacman --remove --noconfirm --noprogressbar#{expand_options(@new_resource.options)} #{name}"
          )
        end

        def purge_package(name, version)
          remove_package(name, version)
        end

      end
    end
  end
end