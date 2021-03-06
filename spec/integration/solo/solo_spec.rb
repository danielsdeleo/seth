require 'support/shared/integration/integration_helper'
require 'seth/mixin/shell_out'
require 'seth/run_lock'
require 'seth/config'
require 'timeout'
require 'fileutils'

describe "seth-solo" do
  extend IntegrationSupport
  include Seth::Mixin::ShellOut

  let(:seth_dir) { File.join(File.dirname(__FILE__), "..", "..", "..") }

  when_the_repository "has a cookbook with a basic recipe" do
    file 'cookbooks/x/metadata.rb', 'version "1.0.0"'
    file 'cookbooks/x/recipes/default.rb', 'puts "ITWORKS"'

    it "should complete with success" do
      file 'config/solo.rb', <<EOM
cookbook_path "#{path_to('cookbooks')}"
file_cache_path "#{path_to('config/cache')}"
EOM
      result = shell_out("ruby bin/seth-solo -c \"#{path_to('config/solo.rb')}\" -o 'x::default' -l debug", :cwd => seth_dir)
      result.error!
      result.stdout.should include("ITWORKS")
    end

    it "should evaluate its node.json file" do
      file 'config/solo.rb', <<EOM
cookbook_path "#{path_to('cookbooks')}"
file_cache_path "#{path_to('config/cache')}"
EOM

      file 'config/node.json',<<-E
{"run_list":["x::default"]}
E

      result = shell_out("ruby bin/seth-solo -c \"#{path_to('config/solo.rb')}\" -j '#{path_to('config/node.json')}' -l debug", :cwd => seth_dir)
      result.error!
      result.stdout.should include("ITWORKS")
    end

  end

  when_the_repository "has a cookbook with an undeclared dependency" do
    file 'cookbooks/x/metadata.rb', 'version "1.0.0"'
    file 'cookbooks/x/recipes/default.rb', 'include_recipe "ancient::aliens"'

    file 'cookbooks/ancient/metadata.rb', 'version "1.0.0"'
    file 'cookbooks/ancient/recipes/aliens.rb', 'print "it was aliens"'

    it "should exit with an error" do
      file 'config/solo.rb', <<EOM
cookbook_path "#{path_to('cookbooks')}"
file_cache_path "#{path_to('config/cache')}"
EOM
      result = shell_out("ruby bin/seth-solo -c \"#{path_to('config/solo.rb')}\" -o 'x::default' -l debug", :cwd => seth_dir)
      result.exitstatus.should == 0 # For seth-5120 this becomes 1
      result.stdout.should include("WARN: MissingCookbookDependency")
    end
  end


  when_the_repository "has a cookbook with a recipe with sleep" do
    directory 'logs'
    file 'logs/runs.log', ''
    file 'cookbooks/x/metadata.rb', 'version "1.0.0"'
    file 'cookbooks/x/recipes/default.rb', <<EOM
ruby_block "sleeping" do
  block do
    sleep 5
  end
end
EOM
    # Ruby 1.8.7 doesn't have Process.spawn :(
    it "while running solo concurrently", :ruby_gte_19_only => true do
      file 'config/solo.rb', <<EOM
cookbook_path "#{path_to('cookbooks')}"
file_cache_path "#{path_to('config/cache')}"
EOM
      # We have a timeout protection here so that if due to some bug
      # run_lock gets stuck we can discover it.
      lambda {
        Timeout.timeout(120) do
          seth_dir = File.join(File.dirname(__FILE__), "..", "..", "..")

          # Instantiate the first seth-solo run
          s1 = Process.spawn("ruby bin/seth-solo -c \"#{path_to('config/solo.rb')}\" -o 'x::default' \
-l debug -L #{path_to('logs/runs.log')}", :chdir => seth_dir)

          # Give it some time to progress
          sleep 1

          # Instantiate the second seth-solo run
          s2 = Process.spawn("ruby bin/seth-solo -c \"#{path_to('config/solo.rb')}\" -o 'x::default' \
-l debug -L #{path_to('logs/runs.log')}", :chdir => seth_dir)

          Process.waitpid(s1)
          Process.waitpid(s2)
        end
      }.should_not raise_error

      # Unfortunately file / directory helpers in integration tests
      # are implemented using before(:each) so we need to do all below
      # checks in one example.
      run_log = File.read(path_to('logs/runs.log'))

      # both of the runs should succeed
      run_log.lines.reject {|l| !l.include? "INFO: Seth Run complete in"}.length.should == 2

      # second run should have a message which indicates it's waiting for the first run
      pid_lines = run_log.lines.reject {|l| !l.include? "Seth-client pid:"}
      pid_lines.length.should == 2
      pids = pid_lines.map {|l| l.split(" ").last}
      run_log.should include("Seth client #{pids[0]} is running, will wait for it to finish and then run.")

      # second run should start after first run ends
      starts = [ ]
      ends = [ ]
      run_log.lines.each_with_index do |line, index|
        if line.include? "Seth-client pid:"
          starts << index
        elsif line.include? "INFO: Seth Run complete in"
          ends << index
        end
      end
      starts[1].should > ends[0]
    end

  end
end
