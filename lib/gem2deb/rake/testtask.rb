require 'rake/testtask'

module Gem2Deb
  module Rake
    class TestTask < ::Rake::TestTask
      def initialize
        super(:default)
        self.libs = []
      end
    end
  end
end
