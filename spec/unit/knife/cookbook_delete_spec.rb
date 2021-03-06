#
# Author:: Thomas Bishop (<bishop.thomas@gmail.com>)
# Copyright:: Copyright (c) 2011 Thomas Bishop
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

require 'spec_helper'

describe Seth::ceth::CookbookDelete do
  before(:each) do
    @ceth = Seth::ceth::CookbookDelete.new
    @ceth.name_args = ['foobar']
    @ceth.cookbook_name = 'foobar'
    @stdout = StringIO.new
    @ceth.ui.stub(:stdout).and_return(@stdout)
    @stderr = StringIO.new
    @ceth.ui.stub(:stderr).and_return(@stderr)
  end

  describe 'run' do
    it 'should print usage and exit when a cookbook name is not provided' do
      @ceth.name_args = []
      @ceth.should_receive(:show_usage)
      @ceth.ui.should_receive(:fatal)
      lambda { @ceth.run }.should raise_error(SystemExit)
    end

    describe 'when specifying a cookbook name' do
      it 'should delete the cookbook without a specific version' do
        @ceth.should_receive(:delete_without_explicit_version)
        @ceth.run
      end

      describe 'and a version' do
        it 'should delete the specific version of the cookbook' do
          @ceth.name_args << '1.0.0'
          @ceth.should_receive(:delete_explicit_version)
          @ceth.run
        end
      end

      describe 'with -a or --all' do
        it 'should delete all versions of the cookbook' do
          @ceth.config[:all] = true
          @ceth.should_receive(:delete_all_versions)
          @ceth.run
        end
      end

      describe 'with -p or --purge' do
        it 'should prompt to purge the files' do
          @ceth.config[:purge] = true
          @ceth.should_receive(:confirm).
                 with(/.+Are you sure you want to purge files.+/)
          @ceth.should_receive(:delete_without_explicit_version)
          @ceth.run
        end
      end
    end
  end

  describe 'delete_explicit_version' do
    it 'should delete the specific cookbook version' do
      @ceth.cookbook_name = 'foobar'
      @ceth.version = '1.0.0'
      @ceth.should_receive(:delete_object).with(Seth::CookbookVersion,
                                                 'foobar version 1.0.0',
                                                 'cookbook').and_yield()
      @ceth.should_receive(:delete_request).with('cookbooks/foobar/1.0.0')
      @ceth.delete_explicit_version
    end
  end

  describe 'delete_all_versions' do
    it 'should prompt to delete all versions of the cookbook' do
      @ceth.cookbook_name = 'foobar'
      @ceth.should_receive(:confirm).with('Do you really want to delete all versions of foobar')
      @ceth.should_receive(:delete_all_without_confirmation)
      @ceth.delete_all_versions
    end
  end

  describe 'delete_all_without_confirmation' do
    it 'should delete all versions without confirmation' do
      versions = ['1.0.0', '1.1.0']
      @ceth.should_receive(:available_versions).and_return(versions)
      versions.each do |v|
        @ceth.should_receive(:delete_version_without_confirmation).with(v)
      end
      @ceth.delete_all_without_confirmation
    end
  end

  describe 'delete_without_explicit_version' do
    it 'should exit if there are no available versions' do
      @ceth.should_receive(:available_versions).and_return(nil)
      lambda { @ceth.delete_without_explicit_version }.should raise_error(SystemExit)
    end

    it 'should delete the version if only one is found' do
      @ceth.should_receive(:available_versions).at_least(:once).and_return(['1.0.0'])
      @ceth.should_receive(:delete_explicit_version)
      @ceth.delete_without_explicit_version
    end

    it 'should ask which version(s) to delete if multiple are found' do
      @ceth.should_receive(:available_versions).at_least(:once).and_return(['1.0.0', '1.1.0'])
      @ceth.should_receive(:ask_which_versions_to_delete).and_return(['1.0.0', '1.1.0'])
      @ceth.should_receive(:delete_versions_without_confirmation).with(['1.0.0', '1.1.0'])
      @ceth.delete_without_explicit_version
    end
  end

  describe 'available_versions' do
    before(:each) do
      @rest_mock = double('rest')
      @ceth.should_receive(:rest).and_return(@rest_mock)
      @cookbook_data = { 'foobar' => { 'versions' => [{'version' => '1.0.0'},
                                                      {'version' => '1.1.0'},
                                                      {'version' => '2.0.0'} ]}
      }
    end

    it 'should return the list of versions of the cookbook' do
      @rest_mock.should_receive(:get_rest).with('cookbooks/foobar').and_return(@cookbook_data)
      @ceth.available_versions.should == ['1.0.0', '1.1.0', '2.0.0']
    end

    it 'should raise if an error other than HTTP 404 is returned' do
      exception = Net::HTTPServerException.new('500 Internal Server Error', '500')
      @rest_mock.should_receive(:get_rest).and_raise(exception)
      lambda { @ceth.available_versions }.should raise_error Net::HTTPServerException
    end

    describe "if the cookbook can't be found" do
      before(:each) do
        @rest_mock.should_receive(:get_rest).
          and_raise(Net::HTTPServerException.new('404 Not Found', '404'))
      end

      it 'should print an error' do
        @ceth.available_versions
        @stderr.string.should match /error.+cannot find a cookbook named foobar/i
      end

      it 'should return nil' do
        @ceth.available_versions.should == nil
      end
    end
  end

  describe 'ask_which_version_to_delete' do
    before(:each) do
      @ceth.stub(:available_versions).and_return(['1.0.0', '1.1.0', '2.0.0'])
    end

    it 'should prompt the user to select a version' do
      prompt = /Which version\(s\) do you want to delete\?.+1\. foobar 1\.0\.0.+2\. foobar 1\.1\.0.+3\. foobar 2\.0\.0.+4\. All versions.+/m
      @ceth.should_receive(:ask_question).with(prompt).and_return('1')
      @ceth.ask_which_versions_to_delete
    end

    it "should print an error and exit if a version wasn't specified" do
      @ceth.should_receive(:ask_question).and_return('')
      @ceth.ui.should_receive(:error).with(/no versions specified/i)
      lambda { @ceth.ask_which_versions_to_delete }.should raise_error(SystemExit)
    end

    it 'should print an error if an invalid choice was selected' do
      @ceth.should_receive(:ask_question).and_return('100')
      @ceth.ui.should_receive(:error).with(/100 is not a valid choice/i)
      @ceth.ask_which_versions_to_delete
    end

    it 'should return the selected versions' do
      @ceth.should_receive(:ask_question).and_return('1, 3')
      @ceth.ask_which_versions_to_delete.should == ['1.0.0', '2.0.0']
    end

    it "should return all of the versions if 'all' was selected" do
      @ceth.should_receive(:ask_question).and_return('4')
      @ceth.ask_which_versions_to_delete.should == [:all]
    end
  end

  describe 'delete_version_without_confirmation' do
    it 'should delete the cookbook version' do
      @ceth.should_receive(:delete_request).with('cookbooks/foobar/1.0.0')
      @ceth.delete_version_without_confirmation('1.0.0')
    end

    it 'should output that the cookbook was deleted' do
      @ceth.stub(:delete_request)
      @ceth.delete_version_without_confirmation('1.0.0')
      @stdout.string.should match /deleted cookbook\[foobar\]\[1.0.0\]/im
    end

    describe 'with --print-after' do
      it 'should display the cookbook data' do
        object = ''
        @ceth.config[:print_after] = true
        @ceth.stub(:delete_request).and_return(object)
        @ceth.should_receive(:format_for_display).with(object)
        @ceth.delete_version_without_confirmation('1.0.0')
      end
    end
  end

  describe 'delete_versions_without_confirmation' do
    it 'should delete each version without confirmation' do
      versions = ['1.0.0', '1.1.0']
      versions.each do |v|
        @ceth.should_receive(:delete_version_without_confirmation).with(v)
      end
      @ceth.delete_versions_without_confirmation(versions)
    end

    describe 'with -a or --all' do
      it 'should delete all versions without confirmation' do
        versions = [:all]
        @ceth.should_receive(:delete_all_without_confirmation)
        @ceth.delete_versions_without_confirmation(versions)
      end
    end
  end

end
