#
# Author:: Adam Jacob (<adam@opscode.com>)
# Author:: Christopher Walters (<cw@opscode.com>)
# Copyright:: Copyright (c) 2008, 2009 Opscode, Inc.
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

require 'seth/resource'
require 'seth/resource_collection/stepable_iterator'

class Seth
  class ResourceCollection
    include Enumerable

    # Matches a multiple resource lookup specification,
    # e.g., "service[nginx,unicorn]"
    MULTIPLE_RESOURCE_MATCH = /^(.+)\[(.+?),(.+)\]$/

    # Matches a single resource lookup specification,
    # e.g., "service[nginx]"
    SINGLE_RESOURCE_MATCH = /^(.+)\[(.+)\]$/

    attr_reader :iterator

    def initialize
      @resources = Array.new
      @resources_by_name = Hash.new
      @insert_after_idx = nil
    end

    def all_resources
      @resources
    end

    def [](index)
      @resources[index]
    end

    def []=(index, arg)
      is_seth_resource(arg)
      @resources[index] = arg
      @resources_by_name[arg.to_s] = index
    end

    def <<(*args)
      args.flatten.each do |a|
        is_seth_resource(a)
        @resources << a
        @resources_by_name[a.to_s] = @resources.length - 1
      end
      self
    end

    # 'push' is an alias method to <<
    alias_method :push, :<<

    def insert(resource)
      is_seth_resource(resource)
      if @insert_after_idx
        # in the middle of executing a run, so any resources inserted now should
        # be placed after the most recent addition done by the currently executing
        # resource
        @resources.insert(@insert_after_idx + 1, resource)
        # update name -> location mappings and register new resource
        @resources_by_name.each_key do |key|
          @resources_by_name[key] += 1 if @resources_by_name[key] > @insert_after_idx
        end
        @resources_by_name[resource.to_s] = @insert_after_idx + 1
        @insert_after_idx += 1
      else
        @resources << resource
        @resources_by_name[resource.to_s] = @resources.length - 1
      end
    end

    def each
      @resources.each do |resource|
        yield resource
      end
    end

    def execute_each_resource(&resource_exec_block)
      @iterator = StepableIterator.for_collection(@resources)
      @iterator.each_with_index do |resource, idx|
        @insert_after_idx = idx
        yield resource
      end
    end

    def each_index
      @resources.each_index do |i|
        yield i
      end
    end

    def empty?
      @resources.empty?
    end

    def lookup(resource)
      lookup_by = nil
      if resource.kind_of?(Seth::Resource)
        lookup_by = resource.to_s
      elsif resource.kind_of?(String)
        lookup_by = resource
      else
        raise ArgumentError, "Must pass a Seth::Resource or String to lookup"
      end
      res = @resources_by_name[lookup_by]
      unless res
        raise Seth::Exceptions::ResourceNotFound, "Cannot find a resource matching #{lookup_by} (did you define it first?)"
      end
      @resources[res]
    end

    # Find existing resources by searching the list of existing resources.  Possible
    # forms are:
    #
    # find(:file => "foobar")
    # find(:file => [ "foobar", "baz" ])
    # find("file[foobar]", "file[baz]")
    # find("file[foobar,baz]")
    #
    # Returns the matching resource, or an Array of matching resources.
    #
    # Raises an ArgumentError if you feed it bad lookup information
    # Raises a Runtime Error if it can't find the resources you are looking for.
    def find(*args)
      results = Array.new
      args.each do |arg|
        case arg
        when Hash
          results << find_resource_by_hash(arg)
        when String
          results << find_resource_by_string(arg)
        else
          msg = "arguments to #{self.class.name}#find should be of the form :resource => 'name' or resource[name]"
          raise Seth::Exceptions::InvalidResourceSpecification, msg
        end
      end
      flat_results = results.flatten
      flat_results.length == 1 ? flat_results[0] : flat_results
    end

    # resources is a poorly named, but we have to maintain it for back
    # compat.
    alias_method :resources, :find


    # Returns true if +query_object+ is a valid string for looking up a
    # resource, or raises InvalidResourceSpecification if not.
    # === Arguments
    # * query_object should be a string of the form
    # "resource_type[resource_name]", a single element Hash (e.g., :service =>
    # "apache2"), or a Seth::Resource (this is the happy path). Other arguments
    # will raise an exception.
    # === Returns
    # * true returns true for all valid input.
    # === Raises
    # * Seth::Exceptions::InvalidResourceSpecification for all invalid input.
    def validate_lookup_spec!(query_object)
      case query_object
      when Seth::Resource
        true
      when SINGLE_RESOURCE_MATCH, MULTIPLE_RESOURCE_MATCH
        true
      when Hash
        true
      when String
        raise Seth::Exceptions::InvalidResourceSpecification,
          "The string `#{query_object}' is not valid for resource collection lookup. Correct syntax is `resource_type[resource_name]'"
      else
        raise Seth::Exceptions::InvalidResourceSpecification,
          "The object `#{query_object.inspect}' is not valid for resource collection lookup. " +
          "Use a String like `resource_type[resource_name]' or a Seth::Resource object"
      end
    end

    # Serialize this object as a hash
    def to_json(*a)
      instance_vars = Hash.new
      self.instance_variables.each do |iv|
        instance_vars[iv] = self.instance_variable_get(iv)
      end
      results = {
        'json_class' => self.class.name,
        'instance_vars' => instance_vars
      }
      results.to_json(*a)
    end

    def self.json_create(o)
      collection = self.new()
      o["instance_vars"].each do |k,v|
        collection.instance_variable_set(k.to_sym, v)
      end
      collection
    end

    private

      def find_resource_by_hash(arg)
        results = Array.new
        arg.each do |resource_name, name_list|
          names = name_list.kind_of?(Array) ? name_list : [ name_list ]
          names.each do |name|
            res_name = "#{resource_name.to_s}[#{name}]"
            results << lookup(res_name)
          end
        end
        return results
      end

      def find_resource_by_string(arg)
        results = Array.new
        case arg
        when MULTIPLE_RESOURCE_MATCH
          resource_type = $1
          arg =~ /^.+\[(.+)\]$/
          resource_list = $1
          resource_list.split(",").each do |name|
            resource_name = "#{resource_type}[#{name}]"
            results << lookup(resource_name)
          end
        when SINGLE_RESOURCE_MATCH
          resource_type = $1
          name = $2
          resource_name = "#{resource_type}[#{name}]"
          results << lookup(resource_name)
        else
          raise ArgumentError, "Bad string format #{arg}, you must have a string like resource_type[name]!"
        end
        return results
      end

      def is_seth_resource(arg)
        unless arg.kind_of?(Seth::Resource)
          raise ArgumentError, "Members must be Seth::Resource's"
        end
        true
      end
  end
end
