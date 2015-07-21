require 'rake/testtask'

module Gem2Deb
  module Rake
    class TestTask < ::Rake::TestTask
      def initialize
        super(:default)
      end
      def define(args, &task_block)
        self.libs.reject! { |path| ['lib','ext'].include?(path) }
        self.verbose = true
        self.options = '-v'
        super
      end
    end
  end
end
