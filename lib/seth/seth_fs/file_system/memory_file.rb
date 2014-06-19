require 'seth/chef_fs/file_system/base_fs_object'

class Seth
  module SethFS
    module FileSystem
      class MemoryFile < Seth::ChefFS::FileSystem::BaseFSObject
        def initialize(name, parent, value)
          super(name, parent)
          @value = value
        end
        def read
          return @value
        end
      end
    end
  end
end
