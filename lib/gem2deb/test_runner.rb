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
require 'fileutils'

module Gem2Deb
  class TestRunner

    include FileUtils::Verbose

    attr_accessor :autopkgtest

    def load_path
      if self.autopkgtest
        return ['.']
      end

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
        dirs += Dir.glob('debian/*/' + dir).map { |d| File.expand_path(d) }
      end

      # And we add the current directory:
      dirs << "."

      dirs
    end

    # Override in subclasses
    def run_tests
    end

    # override in subclasses
    def required_file
      nil
    end

    def activate?
      required_file && File.exist?(required_file)
    end

    def run_ruby(*cmd)
      rubylib = load_path.join(':')
      cmd.unshift(rubyver)
      if $VERBOSE
        print "RUBYLIB=#{rubylib} "
        puts cmd.map { |part| part =~ /['"]/ ? part.inspect : part }.join(' ')
      end
      ENV['RUBYLIB'] = (ENV['RUBYLIB'] ? ENV['RUBYLIB'] + ':' : '') + rubylib
      if autopkgtest
        move_away 'lib'
        move_away 'ext'
      end
      system(*cmd)
      exitstatus = $?.exitstatus
      if autopkgtest
        restore 'lib'
        restore 'ext'
      end
      exit(exitstatus)
    end

    def move_away(dir)
      if File.exist?(dir)
        mv dir, '.gem2deb.' + dir
      end
    end

    def restore(dir)
      if File.exist?('.gem2deb.' + dir)
        mv '.gem2deb.' + dir, dir
      end
    end

    def self.inherited(subclass)
      @subclasses ||= []
      @subclasses << subclass
    end
    def self.subclasses
      @subclasses
    end
    def self.detect
      subclasses.map(&:new).find do |runner|
        runner.activate?
      end
    end
    def self.detect!
      detect || bail("E: this tool must be run from inside a Debian source package.")
    end
    def self.bail(msg)
      puts msg
      exit 1
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
      def run_tests
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
      def run_tests
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
      def run_tests
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
      def run_tests
        puts "Running tests for #{rubyver}: found no way to run a test suite!"
      end
    end

  end

end
