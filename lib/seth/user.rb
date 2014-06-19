#
# Author:: Steven Danna (steve@opscode.com)
# Copyright:: Copyright 2012 Opscode, Inc.
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
require 'seth/mixin/params_validate'
require 'seth/mixin/from_file'
require 'seth/mash'
require 'seth/json_compat'
require 'seth/search/query'

class Seth
  class User

    include Seth::Mixin::FromFile
    include Seth::Mixin::ParamsValidate

    def initialize
      @name = ''
      @public_key = nil
      @private_key = nil
      @password = nil
      @admin = false
    end

    def name(arg=nil)
      set_or_return(:name, arg,
                    :regex => /^[a-z0-9\-_]+$/)
    end

    def admin(arg=nil)
      set_or_return(:admin,
                    arg, :kind_of => [TrueClass, FalseClass])
    end

    def public_key(arg=nil)
      set_or_return(:public_key,
                    arg, :kind_of => String)
    end

    def private_key(arg=nil)
      set_or_return(:private_key,
                    arg, :kind_of => String)
    end

    def password(arg=nil)
      set_or_return(:password,
                    arg, :kind_of => String)
    end

    def to_hash
      result = {
        "name" => @name,
        "public_key" => @public_key,
        "admin" => @admin
      }
      result["private_key"] = @private_key if @private_key
      result["password"] = @password if @password
      result
    end

    def to_json(*a)
      to_hash.to_json(*a)
    end

    def destroy
      Seth::REST.new(Chef::Config[:seth_server_url]).delete_rest("users/#{@name}")
    end

    def create
      payload = {:name => self.name, :admin => self.admin, :password => self.password }
      payload[:public_key] = public_key if public_key
      new_user =Seth::REST.new(Chef::Config[:seth_server_url]).post_rest("users", payload)
      Seth::User.from_hash(self.to_hash.merge(new_user))
    end

    def update(new_key=false)
      payload = {:name => name, :admin => admin}
      payload[:private_key] = new_key if new_key
      payload[:password] = password if password
      updated_user = Seth::REST.new(Chef::Config[:seth_server_url]).put_rest("users/#{name}", payload)
      Seth::User.from_hash(self.to_hash.merge(updated_user))
    end

    def save(new_key=false)
      begin
        create
      rescue Net::HTTPServerException => e
        if e.response.code == "409"
          update(new_key)
        else
          raise e
        end
      end
    end

    def reregister
      r = Seth::REST.new(Chef::Config[:seth_server_url])
      reregistered_self = r.put_rest("users/#{name}", { :name => name, :admin => admin, :private_key => true })
      private_key(reregistered_self["private_key"])
      self
    end

    def to_s
      "user[#{@name}]"
    end

    def inspect
      "Seth::User name:'#{name}' admin:'#{admin.inspect}'" +
      "public_key:'#{public_key}' private_key:#{private_key}"
    end

    # Class Methods

    def self.from_hash(user_hash)
      user = Seth::User.new
      user.name user_hash['name']
      user.private_key user_hash['private_key'] if user_hash.key?('private_key')
      user.password user_hash['password'] if user_hash.key?('password')
      user.public_key user_hash['public_key']
      user.admin user_hash['admin']
      user
    end

    def self.from_json(json)
      Seth::User.from_hash(Chef::JSONCompat.from_json(json))
    end

    class << self
      alias_method :json_create, :from_json
    end

    def self.list(inflate=false)
      response = Seth::REST.new(Chef::Config[:seth_server_url]).get_rest('users')
      users = if response.is_a?(Array)
        transform_ohc_list_response(response) # OHC/OPC
      else
        response # OSC
      end
      if inflate
        users.inject({}) do |user_map, (name, _url)|
          user_map[name] = Seth::User.load(name)
          user_map
        end
      else
        users
      end
    end

    def self.load(name)
      response = Seth::REST.new(Chef::Config[:seth_server_url]).get_rest("users/#{name}")
      Seth::User.from_hash(response)
    end

    private

    # Gross.  Transforms an API response in the form of:
    # [ { "user" => { "username" => USERNAME }}, ...]
    # into the form
    # { "USERNAME" => "URI" }
    def self.transform_ohc_list_response(response)
      new_response = Hash.new
      response.each do |u|
        name = u['user']['username']
        new_response[name] = Seth::Config[:seth_server_url] + "/users/#{name}"
      end
      new_response
    end
  end
end
