#
# Author:: Stephen Delano (<stephen@opscode.com>)
# Author:: Seth Falcon (<seth@opscode.com>)
# Author:: John Keiser (<jkeiser@ospcode.com>)
# Author:: Kyle Goodwin (<kgoodwin@primerevenue.com>)
# Copyright:: Copyright 2010-2011 Opscode, Inc.
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

require 'seth/config'
require 'seth/mash'
require 'seth/mixin/params_validate'
require 'seth/mixin/from_file'
require 'seth/version_constraint'

class Seth
  class Environment

    DEFAULT = "default"

    include Seth::Mixin::ParamsValidate
    include Seth::Mixin::FromFile

    COMBINED_COOKBOOK_CONSTRAINT = /(.+)(?:[\s]+)((?:#{Seth::VersionConstraint::OPS.join('|')})(?:[\s]+).+)$/.freeze

    def initialize
      @name = ''
      @description = ''
      @default_attributes = Mash.new
      @override_attributes = Mash.new
      @cookbook_versions = Hash.new
    end

    def seth_server_rest
      Seth::REST.new(seth::Config[:seth_server_url])
    end

    def self.seth_server_rest
      Seth::REST.new(seth::Config[:seth_server_url])
    end

    def name(arg=nil)
      set_or_return(
        :name,
        arg,
        { :regex => /^[\-[:alnum:]_]+$/, :kind_of => String }
      )
    end

    def description(arg=nil)
      set_or_return(
        :description,
        arg,
        :kind_of => String
      )
    end

    def default_attributes(arg=nil)
      set_or_return(
        :default_attributes,
        arg,
        :kind_of => Hash
      )
    end

    def default_attributes=(attrs)
      default_attributes(attrs)
    end

    def override_attributes(arg=nil)
      set_or_return(
        :override_attributes,
        arg,
        :kind_of => Hash
      )
    end

    def override_attributes=(attrs)
      override_attributes(attrs)
    end

    def cookbook_versions(arg=nil)
      set_or_return(
        :cookbook_versions,
        arg,
        {
          :kind_of => Hash,
          :callbacks => {
            "should be a valid set of cookbook version requirements" => lambda { |cv| Seth::Environment.validate_cookbook_versions(cv) }
          }
        }
      )
    end

    def cookbook(cookbook, version)
      validate({
        :version => version
      },{
        :version => {
          :callbacks => { "should be a valid version requirement" => lambda { |v| Seth::Environment.validate_cookbook_version(v) } }
        }
      })
      @cookbook_versions[cookbook] = version
    end

    def to_hash
      result = {
        "name" => @name,
        "description" => @description,
        "cookbook_versions" =>  @cookbook_versions,
        "json_class" => self.class.name,
        "seth_type" => "environment",
        "default_attributes" => @default_attributes,
        "override_attributes" => @override_attributes
      }
      result
    end

    def to_json(*a)
      to_hash.to_json(*a)
    end

    def update_from!(o)
      description(o.description)
      cookbook_versions(o.cookbook_versions)
      default_attributes(o.default_attributes)
      override_attributes(o.override_attributes)
      self
    end


    def update_attributes_from_params(params)
      unless params[:default_attributes].nil? || params[:default_attributes].size == 0
        default_attributes(Seth::JSONCompat.from_json(params[:default_attributes]))
      end
      unless params[:override_attributes].nil? || params[:override_attributes].size == 0
        override_attributes(Seth::JSONCompat.from_json(params[:override_attributes]))
      end
    end

    def update_from_params(params)
      # reset because everything we need will be in the params, this is necessary because certain constraints
      # may have been removed in the params and need to be removed from cookbook_versions as well.
      bkup_cb_versions = cookbook_versions
      cookbook_versions(Hash.new)
      valid = true

      begin
        name(params[:name])
      rescue Seth::Exceptions::ValidationFailed => e
        invalid_fields[:name] = e.message
        valid = false
      end
      description(params[:description])

      unless params[:cookbook_version].nil?
        params[:cookbook_version].each do |index, cookbook_constraint_spec|
          unless (cookbook_constraint_spec.nil? || cookbook_constraint_spec.size == 0)
            valid = valid && update_cookbook_constraint_from_param(index, cookbook_constraint_spec)
          end
        end
      end

      update_attributes_from_params(params)

      valid = validate_required_attrs_present && valid
      cookbook_versions(bkup_cb_versions) unless valid # restore the old cookbook_versions if valid is false
      valid
    end

    def update_cookbook_constraint_from_param(index, cookbook_constraint_spec)
      valid = true
      md = cookbook_constraint_spec.match(COMBINED_COOKBOOK_CONSTRAINT)
      if md.nil? || md[2].nil?
        valid = false
        add_cookbook_constraint_error(index, cookbook_constraint_spec)
      elsif self.class.validate_cookbook_version(md[2])
        cookbook_versions[md[1]] = md[2]
      else
        valid = false
        add_cookbook_constraint_error(index, cookbook_constraint_spec)
      end
      valid
    end

    def add_cookbook_constraint_error(index, cookbook_constraint_spec)
      invalid_fields[:cookbook_version] ||= {}
      invalid_fields[:cookbook_version][index] = "#{cookbook_constraint_spec} is not a valid cookbook constraint"
    end

    def invalid_fields
      @invalid_fields ||= {}
    end

    def validate_required_attrs_present
      if name.nil? || name.size == 0
        invalid_fields[:name] ||= "name cannot be empty"
        false
      else
        true
      end
    end


    def self.json_create(o)
      environment = new
      environment.name(o["name"])
      environment.description(o["description"])
      environment.cookbook_versions(o["cookbook_versions"])
      environment.default_attributes(o["default_attributes"])
      environment.override_attributes(o["override_attributes"])
      environment
    end

    def self.list(inflate=false)
      if inflate
        response = Hash.new
        Seth::Search::Query.new.search(:environment) do |e|
          response[e.name] = e unless e.nil?
        end
        response
      else
        seth_server_rest.get_rest("environments")
      end
    end

    def self.load(name)
      if Seth::Config[:solo]
        load_from_file(name)
      else
        seth_server_rest.get_rest("environments/#{name}")
      end
    end

    def self.load_from_file(name)
      unless File.directory?(Seth::Config[:environment_path])
        raise Seth::Exceptions::InvalidEnvironmentPath, "Environment path '#{seth::Config[:environment_path]}' is invalid"
      end

      js_file = File.join(Seth::Config[:environment_path], "#{name}.json")
      rb_file = File.join(Seth::Config[:environment_path], "#{name}.rb")

      if File.exists?(js_file)
        # from_json returns object.class => json_class in the JSON.
        Seth::JSONCompat.from_json(IO.read(js_file))
      elsif File.exists?(rb_file)
        environment = Seth::Environment.new
        environment.name(name)
        environment.from_file(rb_file)
        environment
      else
        raise Seth::Exceptions::EnvironmentNotFound, "Environment '#{name}' could not be loaded from disk"
      end
    end

    def destroy
      seth_server_rest.delete_rest("environments/#{@name}")
    end

    def save
      begin
        seth_server_rest.put_rest("environments/#{@name}", self)
      rescue Net::HTTPServerException => e
        raise e unless e.response.code == "404"
        seth_server_rest.post_rest("environments", self)
      end
      self
    end

    def create
      seth_server_rest.post_rest("environments", self)
      self
    end

    def self.load_filtered_recipe_list(environment)
      seth_server_rest.get_rest("environments/#{environment}/recipes")
    end

    def to_s
      @name
    end

    def self.validate_cookbook_versions(cv)
      return false unless cv.kind_of?(Hash)
      cv.each do |cookbook, version|
        return false unless Seth::Environment.validate_cookbook_version(version)
      end
      true
    end

    def self.validate_cookbook_version(version)
      begin
        if Seth::Config[:solo]
          raise Seth::Exceptions::IllegalVersionConstraint,
                "Environment cookbook version constraints not allowed in seth-solo"
        else
          Seth::VersionConstraint.new version
          true
        end
      rescue ArgumentError
        false
      end
    end

  end
end
