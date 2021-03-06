# Author:: Daniel DeLeo (<dan@kallistec.com>)
# Copyright:: Copyright (c) 2009 Daniel DeLeo
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
require "ostruct"

ObjectTestHarness = Proc.new do
  extend Shell::Extensions::ObjectCoreExtensions

  def conf=(new_conf)
    @conf = new_conf
  end

  def conf
    @conf
  end

  desc "rspecin'"
  def rspec_method
  end
end

class TestJobManager
  attr_accessor :jobs
end

describe Shell do

  before do
    Shell.irb_conf = {}
    Shell::ShellSession.instance.stub(:reset!)
  end

  describe "reporting its status" do

    it "alway says it is running" do
      Shell.should be_running
    end

  end

  describe "configuring IRB" do
    it "configures irb history" do
      Shell.configure_irb
      Shell.irb_conf[:HISTORY_FILE].should == "~/.seth/seth_shell_history"
      Shell.irb_conf[:SAVE_HISTORY].should == 1000
    end

    it "has a prompt like ``seth > '' in the default context" do
      Shell.configure_irb

      conf = OpenStruct.new
      conf.main = Object.new
      conf.main.instance_eval(&ObjectTestHarness)
      Shell.irb_conf[:IRB_RC].call(conf)
      conf.prompt_c.should      == "seth > "
      conf.return_format.should == " => %s \n"
      conf.prompt_i.should      == "seth > "
      conf.prompt_n.should      == "seth ?> "
      conf.prompt_s.should      == "seth%l> "
      conf.use_tracer.should    == false
    end

    it "has a prompt like ``seth:recipe > '' in recipe context" do
      Shell.configure_irb

      conf = OpenStruct.new
      events = Seth::EventDispatch::Dispatcher.new
      conf.main = Seth::Recipe.new(nil,nil,seth::RunContext.new(seth::Node.new, {}, events))
      Shell.irb_conf[:IRB_RC].call(conf)
      conf.prompt_c.should      == "seth:recipe > "
      conf.prompt_i.should      == "seth:recipe > "
      conf.prompt_n.should      == "seth:recipe ?> "
      conf.prompt_s.should      == "seth:recipe%l> "
    end

    it "has a prompt like ``seth:attributes > '' in attributes/node context" do
      Shell.configure_irb

      conf = OpenStruct.new
      conf.main = Seth::Node.new
      Shell.irb_conf[:IRB_RC].call(conf)
      conf.prompt_c.should      == "seth:attributes > "
      conf.prompt_i.should      == "seth:attributes > "
      conf.prompt_n.should      == "seth:attributes ?> "
      conf.prompt_s.should      == "seth:attributes%l> "
    end

  end

  describe "convenience macros for creating the seth object" do

    before do
      @seth_object = Object.new
      @seth_object.instance_eval(&ObjectTestHarness)
    end

    it "creates help text for methods with descriptions" do
      @seth_object.help_descriptions.should == [Shell::Extensions::Help.new("rspec_method", "rspecin'", nil)]
    end

    it "adds help text when a new method is described then defined" do
      describe_define =<<-EVAL
        desc "foo2the Bar"
        def baz
        end
      EVAL
      @seth_object.instance_eval describe_define
      @seth_object.help_descriptions.should == [Shell::Extensions::Help.new("rspec_method", "rspecin'"),
                                                Shell::Extensions::Help.new("baz", "foo2the Bar")]
    end

    it "adds help text for subcommands" do
      describe_define =<<-EVAL
        subcommands :baz_obj_command => "something you can do with baz.baz_obj_command"
        def baz
        end
      EVAL
      @seth_object.instance_eval describe_define
      expected_help_text_fragments = [Shell::Extensions::Help.new("rspec_method", "rspecin'")]
      expected_help_text_fragments << Shell::Extensions::Help.new("baz.baz_obj_command", "something you can do with baz.baz_obj_command")
      @seth_object.help_descriptions.should == expected_help_text_fragments
    end

    it "doesn't add previous subcommand help to commands defined afterward" do
      describe_define =<<-EVAL
        desc "swingFromTree"
        def monkey_time
        end

        def super_monkey_time
        end

      EVAL
      @seth_object.instance_eval describe_define
      @seth_object.help_descriptions.should have(2).descriptions
      @seth_object.help_descriptions.select {|h| h.cmd == "super_monkey_time" }.should be_empty
    end

    it "creates a help banner with the command descriptions" do
      @seth_object.help_banner.should match(/^\|\ Command[\s]+\|\ Description[\s]*$/)
      @seth_object.help_banner.should match(/^\|\ rspec_method[\s]+\|\ rspecin\'[\s]*$/)
    end
  end

end
