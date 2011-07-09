require 'rake/testtask'

module Gem2Deb
  module Rake
    class TestTask < ::Rake::TestTask
      def initialize
        super(:default)
      end
      def define
        self.libs.reject! { |path| ['lib','ext'].include?(path) }
        super
      end
    end
  end
end
