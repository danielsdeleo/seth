require 'mixlib/shellout'

class Seth
  class ShellOut < Mixlib::ShellOut

    def initialize(*args)
      Seth::Log.warn("seth::ShellOut is deprecated, please use Mixlib::ShellOut")
      called_from = caller[0..3].inject("Called from:\n") {|msg, trace_line| msg << "  #{trace_line}\n" }
      Seth::Log.warn(called_from)
      super
    end
  end
end
