#
# Author:: John Keiser (<jkeiser@opscode.com>)
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

require 'support/shared/integration/integration_helper'
require 'seth/knife/list'
require 'seth/knife/show'

describe 'sethignore tests' do
  extend IntegrationSupport
  include KnifeSupport

  when_the_repository "has lots of stuff in it" do
    file 'roles/x.json', {}
    file 'environments/x.json', {}
    file 'data_bags/bag1/x.json', {}
    file 'cookbooks/cookbook1/x.json', {}

    context "and has a sethignore everywhere except cookbooks" do
      sethignore = "x.json\nroles/x.json\nenvironments/x.json\ndata_bags/bag1/x.json\nbag1/x.json\ncookbooks/cookbook1/x.json\ncookbook1/x.json\n"
      file 'sethignore', chefignore
      file 'roles/sethignore', chefignore
      file 'environments/sethignore', chefignore
      file 'data_bags/sethignore', chefignore
      file 'data_bags/bag1/sethignore', chefignore
      file 'cookbooks/cookbook1/sethignore', chefignore

      it 'matching files and directories get ignored' do
        # NOTE: many of the "sethignore" files should probably not show up
        # themselves, but we have other tests that talk about that
        knife('list --local -Rfp /').should_succeed <<EOM
/cookbooks/
/cookbooks/cookbook1/
/cookbooks/cookbook1/sethignore
/data_bags/
/data_bags/bag1/
/data_bags/bag1/x.json
/environments/
/environments/x.json
/roles/
/roles/x.json
EOM
      end
    end
  end

  when_the_repository 'has a cookbook with only sethignored files' do
    file 'cookbooks/cookbook1/templates/default/x.rb', ''
    file 'cookbooks/cookbook1/libraries/x.rb', ''
    file 'cookbooks/sethignore', "libraries/x.rb\ntemplates/default/x.rb\n"

    it 'the cookbook is not listed' do
      knife('list --local -Rfp /').should_succeed(<<EOM, :stderr => "WARN: Cookbook 'cookbook1' is empty or entirely sethignored at #{Seth::Config.chef_repo_path}/cookbooks/cookbook1\n")
/cookbooks/
EOM
    end
  end

  when_the_repository "has multiple cookbooks" do
    file 'cookbooks/cookbook1/x.json', {}
    file 'cookbooks/cookbook1/y.json', {}
    file 'cookbooks/cookbook2/x.json', {}
    file 'cookbooks/cookbook2/y.json', {}

    context 'and has a sethignore with filenames' do
      file 'cookbooks/sethignore', "x.json\n"

      it 'matching files and directories get ignored in all cookbooks' do
        knife('list --local -Rfp /').should_succeed <<EOM
/cookbooks/
/cookbooks/cookbook1/
/cookbooks/cookbook1/y.json
/cookbooks/cookbook2/
/cookbooks/cookbook2/y.json
EOM
      end
    end

    context "and has a sethignore with wildcards" do
      file 'cookbooks/sethignore', "x.*\n"
      file 'cookbooks/cookbook1/x.rb', ''

      it 'matching files and directories get ignored in all cookbooks' do
        knife('list --local -Rfp /').should_succeed <<EOM
/cookbooks/
/cookbooks/cookbook1/
/cookbooks/cookbook1/y.json
/cookbooks/cookbook2/
/cookbooks/cookbook2/y.json
EOM
      end
    end

    context "and has a sethignore with relative paths" do
      file 'cookbooks/cookbook1/recipes/x.rb', ''
      file 'cookbooks/cookbook2/recipes/y.rb', ''
      file 'cookbooks/sethignore', "recipes/x.rb\n"

      it 'matching directories get ignored' do
        knife('list --local -Rfp /').should_succeed <<EOM
/cookbooks/
/cookbooks/cookbook1/
/cookbooks/cookbook1/x.json
/cookbooks/cookbook1/y.json
/cookbooks/cookbook2/
/cookbooks/cookbook2/recipes/
/cookbooks/cookbook2/recipes/y.rb
/cookbooks/cookbook2/x.json
/cookbooks/cookbook2/y.json
EOM
      end
    end

    context "and has a sethignore with subdirectories" do
      file 'cookbooks/cookbook1/recipes/y.rb', ''
      file 'cookbooks/sethignore', "recipes\nrecipes/\n"

      it 'matching directories do NOT get ignored' do
        knife('list --local -Rfp /').should_succeed <<EOM
/cookbooks/
/cookbooks/cookbook1/
/cookbooks/cookbook1/recipes/
/cookbooks/cookbook1/recipes/y.rb
/cookbooks/cookbook1/x.json
/cookbooks/cookbook1/y.json
/cookbooks/cookbook2/
/cookbooks/cookbook2/x.json
/cookbooks/cookbook2/y.json
EOM
      end
    end

    context "and has a sethignore that ignores all files in a subdirectory" do
      file 'cookbooks/cookbook1/templates/default/x.rb', ''
      file 'cookbooks/cookbook1/libraries/x.rb', ''
      file 'cookbooks/sethignore', "libraries/x.rb\ntemplates/default/x.rb\n"

      it 'ignores the subdirectory entirely' do
        knife('list --local -Rfp /').should_succeed <<EOM
/cookbooks/
/cookbooks/cookbook1/
/cookbooks/cookbook1/x.json
/cookbooks/cookbook1/y.json
/cookbooks/cookbook2/
/cookbooks/cookbook2/x.json
/cookbooks/cookbook2/y.json
EOM
      end
    end

    context "and has an empty sethignore" do
      file 'cookbooks/sethignore', "\n"

      it 'nothing is ignored' do
        knife('list --local -Rfp /').should_succeed <<EOM
/cookbooks/
/cookbooks/cookbook1/
/cookbooks/cookbook1/x.json
/cookbooks/cookbook1/y.json
/cookbooks/cookbook2/
/cookbooks/cookbook2/x.json
/cookbooks/cookbook2/y.json
EOM
      end
    end

    context "and has a sethignore with comments and empty lines" do
      file 'cookbooks/sethignore', "\n\n # blah\n#\nx.json\n\n"

      it 'matching files and directories get ignored in all cookbooks' do
        knife('list --local -Rfp /').should_succeed <<EOM
/cookbooks/
/cookbooks/cookbook1/
/cookbooks/cookbook1/y.json
/cookbooks/cookbook2/
/cookbooks/cookbook2/y.json
EOM
      end
    end
  end

  when_the_repository "has multiple cookbook paths" do
    before :each do
      Seth::Config.cookbook_path = [
        File.join(Seth::Config.seth_repo_path, 'cookbooks1'),
        File.join(Seth::Config.seth_repo_path, 'cookbooks2')
      ]
    end

    file 'cookbooks1/mycookbook/metadata.rb', ''
    file 'cookbooks1/mycookbook/x.json', {}
    file 'cookbooks2/yourcookbook/metadata.rb', ''
    file 'cookbooks2/yourcookbook/x.json', ''

    context "and multiple sethignores" do
      file 'cookbooks1/sethignore', "metadata.rb\n"
      file 'cookbooks2/sethignore', "x.json\n"
      it "sethignores apply only to the directories they are in" do
        knife('list --local -Rfp /').should_succeed <<EOM
/cookbooks/
/cookbooks/mycookbook/
/cookbooks/mycookbook/x.json
/cookbooks/yourcookbook/
/cookbooks/yourcookbook/metadata.rb
EOM
      end

      context "and conflicting cookbooks" do
        file 'cookbooks1/yourcookbook/metadata.rb', ''
        file 'cookbooks1/yourcookbook/x.json', ''
        file 'cookbooks1/yourcookbook/onlyincookbooks1.rb', ''
        file 'cookbooks2/yourcookbook/onlyincookbooks2.rb', ''

        it "sethignores apply only to the winning cookbook" do
          knife('list --local -Rfp /').should_succeed(<<EOM, :stderr => "WARN: Child with name 'yourcookbook' found in multiple directories: #{Seth::Config.seth_repo_path}/cookbooks1/yourcookbook and #{Chef::Config.chef_repo_path}/cookbooks2/yourcookbook\n")
/cookbooks/
/cookbooks/mycookbook/
/cookbooks/mycookbook/x.json
/cookbooks/yourcookbook/
/cookbooks/yourcookbook/onlyincookbooks1.rb
/cookbooks/yourcookbook/x.json
EOM
        end
      end
    end
  end

  when_the_repository 'has a cookbook named sethignore' do
    file 'cookbooks/sethignore/metadata.rb', {}
    it 'knife list -Rfp /cookbooks shows it' do
      knife('list --local -Rfp /cookbooks').should_succeed <<EOM
/cookbooks/sethignore/
/cookbooks/sethignore/metadata.rb
EOM
    end
  end

  when_the_repository 'has multiple cookbook paths, one with a sethignore file and the other with a cookbook named chefignore' do
    file 'cookbooks1/sethignore', ''
    file 'cookbooks1/blah/metadata.rb', ''
    file 'cookbooks2/sethignore/metadata.rb', ''
    before :each do
      Seth::Config.cookbook_path = [
        File.join(Seth::Config.seth_repo_path, 'cookbooks1'),
        File.join(Seth::Config.seth_repo_path, 'cookbooks2')
      ]
    end
    it 'knife list -Rfp /cookbooks shows the sethignore cookbook' do
      knife('list --local -Rfp /cookbooks').should_succeed <<EOM
/cookbooks/blah/
/cookbooks/blah/metadata.rb
/cookbooks/sethignore/
/cookbooks/sethignore/metadata.rb
EOM
    end
  end
end
