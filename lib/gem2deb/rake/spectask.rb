require 'rspec/core/rake_task'

module Gem2Deb
  module Rake
    class RSpecTask < :: RSpec::Core::RakeTask
      def initialize(name=:default, &task_block)
        super(name, &task_block)
      end
      def define(*args, &task_block)
        self.verbose = true
        self.rspec_opts = '--format documentation'
        super
      end
    end
  end
end
