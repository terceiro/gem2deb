require 'rake/testtask'

module Gem2Deb
  module Rake
    class TestTask < ::Rake::TestTask
      def initialize(name=:default)
        super(name)
      end
      def define
        self.libs.reject! { |path| ['lib','ext'].include?(path) }
        self.verbose = true
        self.options = '-v'
        super
      end
    end
  end
end
