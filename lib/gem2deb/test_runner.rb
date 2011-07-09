# Copyright © 2011, Lucas Nussbaum <lucas@debian.org>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

require 'rbconfig'

module Gem2Deb
  class TestRunner

    def load_path
      # We should only use installation paths for the current Ruby
      # version.
      #
      # We assume that installation has already proceeded into
      # subdirectories of the debian/ directory.
      #
      # It is important that the directories under debian/ $LOAD_PATH in the
      # same order than their system-wide equivalent

      dirs = []
      $LOAD_PATH.grep(/vendor/).each do |dir|
        dirs += Dir.glob('debian/*/' + dir)
      end

      # And we add the current directory:
      dirs << "."

      dirs
    end

    def run_tests
      if activate?
        execute_tests
      end
    end

    # override in subclasses
    def execute_tests
    end

    # override in subclasses
    def required_file
      nil
    end

    def activate?
      required_file && File.exists?(required_file)
    end

    def run_ruby(*cmd)
      rubylib = load_path.join(':')
      cmd.unshift(rubyver)
      if $VERBOSE
        print "RUBYLIB=#{rubylib} "
        puts cmd.map { |part| part =~ /['"]/ ? part.inspect : part }.join(' ')
      end
      ENV['RUBYLIB'] = (ENV['RUBYLIB'] ? ENV['RUBYLIB'] + ':' : '') + rubylib
      exec(*cmd)
    end

    def self.inherited(subclass)
      @subclasses ||= []
      @subclasses << subclass
    end
    def self.subclasses
      @subclasses
    end
    def self.detect_and_run
      subclasses.each do |klass|
        klass.new.run_tests
      end
    end
    def rubyver
      @rubyver ||= RbConfig::CONFIG['ruby_install_name']
    end
    def ruby_binary
      @ruby_binary ||= File.join('/usr/bin', rubyver)
    end

    class TestsListedInMetadata < TestRunner
      def required_file
        'debian/ruby-test-files.yaml'
      end
      def execute_tests
        puts "Running tests for #{rubyver} with test file list from debian/ruby-test-files.yaml ..."
        run_ruby(
          '-ryaml', 
          '-e',
          'YAML.load_file("debian/ruby-test-files.yaml").each { |f| require f }'
        )
      end
    end

    class DebianRakefile < TestRunner
      def required_file
        'debian/ruby-tests.rake'
      end
      def execute_tests
        puts "Running tests for #{rubyver} using debian/ruby-tests.rake ..."
        run_ruby(
          '-rrake',
          '-e',
          'ARGV.unshift("-f", "debian/ruby-tests.rake"); Rake.application.run'
        )
      end
    end

    class DebianRubyFile < TestRunner
      def required_file
        'debian/ruby-tests.rb'
      end
      def execute_tests
        puts "Running tests for #{rubyver} using debian/ruby-tests.rb..."
        ENV['RUBY_TEST_VERSION'] = rubyver
        ENV['RUBY_TEST_BIN'] = ruby_binary
        run_ruby(required_file)
      end
    end

    class DontKnownHowToRunTests < TestRunner
      def required_file
        'debian/rules'
      end
      def execute_tests
        puts "Running tests for #{rubyver}: found no way to run a test suite!"
      end
    end

  end

end

if $PROGRAM_NAME == __FILE__
  if ARGV.length == 0
    Gem2Deb::TestRunner.detect_and_run
  else
    puts "usage: #{File.basename($PROGRAM_NAME)}"
    exit(1)
  end
end

