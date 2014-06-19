#
# Copyright:: Copyright (c) 2014 Seth Software, Inc.
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
require 'seth/mixin/shell_out'

describe Seth::Application do
  include Seth::Mixin::ShellOut

  before do
    @original_argv = ARGV.dup
    ARGV.clear
    @original_env = ENV.to_hash
    ENV.clear
    @app = Seth::Application.new
  end

  after do
    ARGV.replace(@original_argv)
    ENV.clear
    ENV.update(@original_env)
  end

  describe "when proxy options are set in config" do
    before do
      Seth::Config[:http_proxy] = "http://proxy.example.org:8080"
      Seth::Config[:https_proxy] = nil
      Seth::Config[:ftp_proxy] = nil
      Seth::Config[:no_proxy] = nil

      @app.configure_proxy_environment_variables
    end

    it "saves built proxy to ENV which shell_out can use" do
      so = if windows?
        shell_out("echo $env:http_proxy")
      else
        shell_out("echo $http_proxy")
      end

      so.stdout.should == "http://proxy.example.org:8080\n"
    end
  end
end
