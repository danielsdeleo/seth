#
# Author:: Bryan W. Berry (<bryan.berry@gmail.com>)
# Author:: Daniel DeLeo (<dan@kallistec.com>)
# Copyright:: Copyright (c) 2012 Bryan W. Berry
# Copyright:: Copyright (c) 2012 Daniel DeLeo
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

require 'seth'
require 'seth/application'
require 'seth/client'
require 'seth/config'
require 'seth/log'
require 'fileutils'
require 'tempfile'
require 'seth/providers'
require 'seth/resources'

class Seth::Application::Apply < Chef::Application

  banner "Usage: seth-apply [RECIPE_FILE] [-e RECIPE_TEXT] [-s]"


  option :execute,
    :short        => "-e RECIPE_TEXT",
    :long         => "--execute RECIPE_TEXT",
    :description  => "Execute resources supplied in a string",
    :proc         => nil

  option :stdin,
    :short        => "-s",
    :long         => "--stdin",
    :description  => "Execute resources read from STDIN",
    :boolean      => true

  option :log_level,
    :short        => "-l LEVEL",
    :long         => "--log_level LEVEL",
    :description  => "Set the log level (debug, info, warn, error, fatal)",
    :proc         => lambda { |l| l.to_sym }

  option :help,
    :short        => "-h",
    :long         => "--help",
    :description  => "Show this message",
    :on           => :tail,
    :boolean      => true,
    :show_options => true,
    :exit         => 0


  option :version,
    :short        => "-v",
    :long         => "--version",
    :description  => "Show seth version",
    :boolean      => true,
    :proc         => lambda {|v| puts "Seth: #{::Chef::VERSION}"},
    :exit         => 0

  option :why_run,
    :short        => '-W',
    :long         => '--why-run',
    :description  => 'Enable whyrun mode',
    :boolean      => true

  option :color,
    :long         => '--[no-]color',
    :boolean      => true,
    :default      => !Seth::Platform.windows?,
    :description  => "Use colored output, defaults to enabled"

  def initialize
    super
  end

  def reconfigure
    parse_options
    Seth::Config.merge!(config)
    configure_logging
    configure_proxy_environment_variables
  end

  def read_recipe_file(file_name)
    recipe_path = file_name
    unless File.exist?(recipe_path)
      Seth::Application.fatal!("No file exists at #{recipe_path}", 1)
    end
    recipe_path = File.expand_path(recipe_path)
    recipe_fh = open(recipe_path)
    recipe_text = recipe_fh.read
    [recipe_text, recipe_fh]
  end

  def get_recipe_and_run_context
    Seth::Config[:solo] = true
    @seth_client = Seth::Client.new
    @seth_client.run_ohai
    @seth_client.load_node
    @seth_client.build_node
    run_context = if @seth_client.events.nil?
                    Seth::RunContext.new(@seth_client.node, {})
                  else
                    Seth::RunContext.new(@seth_client.node, {}, @chef_client.events)
                  end
    recipe = Seth::Recipe.new("(seth-apply cookbook)", "(chef-apply recipe)", run_context)
    [recipe, run_context]
  end

  # write recipe to temp file, so in case of error,
  # user gets error w/ context
  def temp_recipe_file
    @recipe_fh = Tempfile.open('recipe-temporary-file')
    @recipe_fh.write(@recipe_text)
    @recipe_fh.rewind
    @recipe_filename = @recipe_fh.path
  end

  def run_seth_recipe
    if config[:execute]
      @recipe_text = config[:execute]
      temp_recipe_file
    elsif config[:stdin]
      @recipe_text = STDIN.read
      temp_recipe_file
    else
      @recipe_filename = ARGV[0]
      @recipe_text,@recipe_fh = read_recipe_file @recipe_filename
    end
    recipe,run_context = get_recipe_and_run_context
    recipe.instance_eval(@recipe_text, @recipe_filename, 1)
    runner = Seth::Runner.new(run_context)
    begin
      runner.converge
    ensure
      @recipe_fh.close
    end
  end

  def run_application
    begin
      parse_options
      run_seth_recipe
      Seth::Application.exit! "Exiting", 0
    rescue SystemExit => e
      raise
    rescue Exception => e
      Seth::Application.debug_stacktrace(e)
      Seth::Application.fatal!("#{e.class}: #{e.message}", 1)
    end
  end

    # Get this party started
  def run
    reconfigure
    run_application
  end

end
