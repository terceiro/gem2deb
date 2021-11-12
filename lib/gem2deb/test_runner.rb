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

Encoding.default_external = Encoding::UTF_8

require 'rbconfig'
require 'fileutils'
require 'shellwords'
require 'tmpdir'

require 'gem2deb/banner'
require 'gem2deb/metadata'
require 'gem2deb/source'

module Gem2Deb
  class TestRunner

    include FileUtils::Verbose

    attr_accessor :autopkgtest
    attr_accessor :check_dependencies
    attr_accessor :check_bundler

    def initialize
      @source = Gem2Deb::Source.new
    end

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

    def gem_path
      if self.autopkgtest
        nil
      else
        pattern = "debian/*/usr/**/rubygems-integration/{all,#{ruby_api_version}}"
        local_dirs = Dir.glob(pattern).map do |f|
          File.expand_path(f)
        end
        (local_dirs + Gem.path).join(':')
      end
    end

    def run_tests
      if check_dependencies
        do_check_dependencies
      end
      if check_bundler
        do_check_bundler
      end
      do_run_tests
    end

    def do_check_dependencies
      print_banner "Checking Rubygems dependency resolution on #{rubyver}"
      @source.packages.each do |pkg|
        metadata = Gem2Deb::Metadata.new(pkg[:root])
        if metadata.gemspec
          cmd = [rubyver, '-e', 'gem "%s"' % metadata.name]
          puts "GEM_PATH=#{gem_path} " + cmd.shelljoin
          system({ 'GEM_PATH' => gem_path }, *cmd)
          exitstatus = $?.exitstatus
          if exitstatus != 0
            system 'gem', 'list'
            exit(1)
          end
        else
          fail "E: dependency resolution check requested but no working gemspec available for binary package #{pkg[:binary_package]}"
        end
      end
    end

    def do_check_bundler
      if call(rubyver, '-rbundler', '-e', 'true') != 0
        puts("I: bundler not installed, skipping bundler checks")
      end

      rc = 0

      rc += check_bundler_impl(
        'Checking loading under bundler on %s' % rubyver,
        'gem "%s"',
        [rubyver, '-rbundler/setup']
      )

      rc += check_bundler_impl(
        'Checking loading under a bundler group on %s' % rubyver,
        [
          'group :test do',
          '  gem "%s"',
          'end'
        ].join("\n"),
        [rubyver, '-rbundler', '-e', 'Bundler.require(:test)']

      )

      if rc != 0
        fail "E: failed to load under bundler"
      end
    end

    def check_bundler_impl(title, gemfile, command)
      metadata = Gem2Deb::Metadata.new('.')
      print_banner(title)
      Dir.mktmpdir do |tmpdir|
        Dir.chdir(tmpdir) do
          File.open('Gemfile', 'w') do |f|
            f.puts(gemfile % metadata.name)
          end
          puts("Gemfile:")
          puts('----------------8<----------------8<----------------8<-----------------')
          puts(gemfile % metadata.name)
          puts('----------------8<----------------8<----------------8<-----------------')
          puts()
          call(*command).tap do |rc|
            if rc != 0
              puts "E: Command failed (exit status: #{rc})"
            end
          end
        end
      end
    end

    # Override in subclasses
    def do_run_tests
    end

    # override in subclasses
    def required_file
      nil
    end

    def activate?
      required_file && File.exist?(required_file)
    end

    def run_ruby(*args)
      run(rubyver, *args)
    end

    def run_rake(*args)
      run(rubyver, '-S', 'rake', *args)
    end

    def run(program, *args)
      exitstatus = call(program, *args)
      exitstatus = 1 if exitstatus != 0
      exit(exitstatus)
    end

    def call(program, *args)
      cmd = [program] + args

      rubylib = (ENV['RUBYLIB'] ? ENV['RUBYLIB'] + ':' : '') + load_path.join(':')
      puts "RUBYLIB=#{rubylib} GEM_PATH=#{gem_path} " + cmd.shelljoin

      if autopkgtest
        move_away_list = ['lib', 'ext']
      else
        move_away_list = []
      end
      move_away_list << '**/Gemfile.lock'

      move_away(*move_away_list) do
        system({ 'RUBYLIB' => rubylib, 'GEM_PATH' => gem_path }, *cmd)
        $?.exitstatus
      end
    end

    def move_away(*globs)
      moved = {}
      globs.each do |glob|
        Dir[glob].each do |f|
          moved[f] = File.join(File.dirname(f), '.gem2deb.' + File.basename(f))
        end
      end
      moved.each do |orig,new|
        mv orig, new
      end
      ret = yield
      moved.each do |orig,new|
        mv new, orig
      end
      ret
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
    def ruby_api_version
      RbConfig::CONFIG['ruby_version']
    end
    def ruby_binary
      @ruby_binary ||= File.join('/usr/bin', rubyver)
    end

    def print_banner(msg)
      Gem2Deb::Banner.print(msg)
    end

    class TestsListedInMetadata < TestRunner
      def required_file
        'debian/ruby-test-files.yaml'
      end
      def do_run_tests
        print_banner "Run tests for #{rubyver} from debian/ruby-test-files.yaml"
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
      def do_run_tests
        print_banner "Run tests for #{rubyver} from debian/ruby-tests.rake"
        run_rake('-f', 'debian/ruby-tests.rake')
      end
    end

    class DebianRubyFile < TestRunner
      def required_file
        'debian/ruby-tests.rb'
      end
      def do_run_tests
        print_banner "Run tests for #{rubyver} from debian/ruby-tests.rb"
        ENV['RUBY_TEST_VERSION'] = rubyver
        ENV['RUBY_TEST_BIN'] = ruby_binary
        run_ruby(required_file)
      end
    end

    class DontKnownHowToRunTests < TestRunner
      def required_file
        'debian/rules'
      end
      def do_run_tests
        print_banner "Run tests for #{rubyver}: no test suite!"
        exit(77) if autopkgtest
      end
    end

  end

end
