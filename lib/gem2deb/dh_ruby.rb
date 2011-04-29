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
#
# TODO
# ====
# dh_ruby doesn't handle all the cases that setup.rb could handle. More work is needed.
# see FIXME in the file.
#
# There's a number of things that this class needs to be able to do.
#
# dh_ruby should be configurable with a special file in debian/
#   
# dh_ruby must be able to detect and run test suites. alternatively, the maintainer
# can provide a ruby script in debian/ that will start the test suite.
# Test suites should run with each ruby interpreter.
#
# dh_ruby should do some checking (lintian-like) of ruby-specific stuff. For example,
# it could search for "require 'rubygems'" in libraries, and display warnings
#
# dh_ruby could generate rdoc (not sure if we want this)

require 'gem2deb'
require 'gem2deb/metadata'
require 'find'

module Gem2Deb

  class DhRuby

    SUPPORTED_RUBY_VERSIONS = {
      #name             Ruby binary
      #---------------  -------------------
      'ruby1.8'   => '/usr/bin/ruby1.8',
      'ruby1.9.1' => '/usr/bin/ruby1.9.1',
    }

    DEFAULT_RUBY_VERSION = 'ruby1.8'

    RUBY_CODE_DIR = '/usr/lib/ruby/vendor_ruby'

    include Gem2Deb

    attr_accessor :verbose

    attr_reader :metadata

    def initialize
      @verbose = true
      @bindir = '/usr/bin'
      @skip_checks = nil
      @metadata = Gem2Deb::Metadata.new('.')
    end
    
    def clean
      puts "  Entering dh_ruby --clean" if @verbose
      run_make_clean_on_extensions
      puts "  Leaving dh_ruby --clean" if @verbose
    end

    def configure
      # puts "  Entering dh_ruby --configure" if @verbose
      # puts "  Leaving dh_ruby --configure" if @verbose
    end

    def build
      # puts "  Entering dh_ruby --build" if @verbose
      # puts "  Leaving dh_ruby --build" if @verbose
    end

    def test
      # puts "  Entering dh_ruby --test" if @verbose
      # puts "  Leaving dh_ruby --test" if @verbose
    end

    EXTENSION_BUILDER = File.expand_path(File.join(File.dirname(__FILE__),'extension_builder.rb'))
    TEST_RUNNER = File.expand_path(File.join(File.dirname(__FILE__),'testrunner.rb'))
    LIBDIR = File.expand_path(File.join(File.dirname(__FILE__), '..'))

    def install(argv)
      puts "  Entering dh_ruby --install" if @verbose

      package = packages.first

      install_files('bin', find_files('bin'), File.join(destdir_for(package), @bindir),             755) if File::directory?('bin')

      install_files('lib', find_files('lib'), File.join(destdir_for(package), RUBY_CODE_DIR), 644) if File::directory?('lib')

      # find ruby versions to build the package for.
      l = IO::readlines('debian/control').grep(/^XS-Ruby-Versions: /)
      if l.empty?
        puts "No XS-Ruby-Versions: field found in source!"
        exit(1)
      end
      supported_versions = l[0].split[1..-1]
      if supported_versions.include?('all')
        supported_versions = SUPPORTED_RUBY_VERSIONS.keys
      end

      if metadata.has_native_extensions?
        supported_versions.each do |rubyver|
          puts "Building extension for #{rubyver} ..." if @verbose
          run("#{SUPPORTED_RUBY_VERSIONS[rubyver]} -I#{LIBDIR} #{EXTENSION_BUILDER} #{package}")
          # run tests for this version of ruby
          if not run_tests(rubyver)
            supported_versions.delete(rubyver)
          end
        end
      else
        # run tests for all versions
        tested_versions = supported_versions
        tested_versions.each do |rubyver|
          if not run_tests(rubyver)
            supported_versions.delete(rubyver)
          end
        end
      end

      File::open("debian/#{package}.substvars", "a") do |fd|
        fd.puts "ruby:Versions=#{supported_versions.join(' ')}"
      end

      update_shebangs(package)

      # FIXME after install, check for require 'rubygems' and other stupid things, and
      #       issue warnings

      check_rubygems
      puts "  Leaving dh_ruby --install" if @verbose
    end

    protected

    def check_rubygems
      if skip_checks?
        return
      end
      found = false
      if File::exists?('debian/require-rubygems.overrides')
        overrides = YAML::load_file('debian/require-rubygems.overrides')
      else
        overrides = []
      end
      packages.each do |pkg|
        pkg.chomp!
        Dir["debian/#{pkg}/usr/lib/ruby/vendor_ruby/**/*.rb"].each do |f|
          lines = IO::readlines(f)
          rglines = lines.select { |l| l =~ /require.*rubygems/ }
          rglines.each do |l|
            if not overrides.include?(f)
              puts "#{f}: #{l}"
              found = true
            end
          end
        end
      end
      if found
        puts "Found some 'require rubygems' without overrides (see above)."
        handle_test_failure('require-rubygems')
      end
    end

    def handle_test_failure(test)
      if ENV['DH_RUBY_IGNORE_TESTS']
        if ENV['DH_RUBY_IGNORE_TESTS'].split.include?('all')
          puts "WARNING: Test \"#{test}\" failed, but ignoring all test results."
          return
        elsif ENV['DH_RUBY_IGNORE_TESTS'].split.include?(test)
          puts "WARNING: Test \"#{test}\" failed, but ignoring this test result."
          return
        end
      end
      if STDIN.isatty and STDOUT.isatty and STDERR.isatty
        # running interactively
        continue = nil
        begin
          puts
          print "Test \"#{test}\" failed. Continue building the package? (Y/N) "
          STDOUT.flush
          c = STDIN.getc
          continue = true if c.chr.downcase == 'y'
          continue = false if c.chr.downcase == 'n'
        end while continue.nil?
        if not continue
          exit(1)
        end
      else
          puts "ERROR: Test \"#{test}\" failed. Exiting."
          exit(1)
      end
    end

    def run_tests(rubyver)
      if skip_checks?
        return
      end
      if File::exists?('debian/ruby-test-files.yaml')
        puts "Running tests for #{rubyver} using gem2deb test runner and debian/ruby-test-files.yaml..."
        cmd = "#{SUPPORTED_RUBY_VERSIONS[rubyver]} -I#{LIBDIR} #{TEST_RUNNER}"
        puts(cmd) if $VERBOSE
        system(cmd)
      elsif File::exists?('debian/ruby-tests.rb')
        puts "Running tests for #{rubyver} using debian/ruby-tests.rb..."
        ENV['RUBY_TEST_VERSION'] = rubyver
        ENV['RUBY_TEST_BIN'] = SUPPORTED_RUBY_VERSIONS[rubyver]
        cmd = "#{SUPPORTED_RUBY_VERSIONS[rubyver]} -Ilib debian/ruby-tests.rb"
        puts(cmd) if $VERBOSE
        system(cmd)
      else
        puts "Running tests for #{rubyver}: found no way to run a test suite!"
      end
      if $?.exitstatus != 0
        handle_test_failure(rubyver)
        return false
      else
        return true
      end
    end

    def skip_checks?
      if @skip_checks.nil?
        if ENV['DEB_BUILD_OPTIONS'] && ENV['DEB_BUILD_OPTIONS'].split(' ').include?('nocheck')
          puts "DEB_BUILD_OPTIONS includes nocheck, skipping all checks (test suite, rubygems usage etc)." if @verbose
          @skip_checks = true
        else
          @skip_checks = false
        end
      end
      @skip_checks
    end

    JUNK_FILES = %w( RCSLOG tags TAGS .make.state .nse_depinfo )
    HOOK_FILES = %w( pre-%s post-%s pre-%s.rb post-%s.rb ).map {|fmt|
      %w( config setup install clean ).map {|t| sprintf(fmt, t) }
      }.flatten
    JUNK_PATTERNS = [ /^#/, /^\.#/, /^cvslog/, /^,/, /^\.del-*/, /\.olb$/,
        /~$/, /\.(old|bak|BAK|orig|rej)$/, /^_\$/, /\$$/, /\.org$/, /\.in$/, /^\./ ]

    def find_files(dir, accept_pattern=nil)
      files = []
      Dir::chdir(dir) do
        Find::find('.') do |f|
          files << f.gsub(/^\.\//, '') # hack hack
        end
      end
      files = files - ['.'] # hack hack
      files2 = []
      files.each do |f|
        fb = File::basename(f)
        next if (JUNK_FILES + HOOK_FILES).include?(fb)
        next if JUNK_PATTERNS.select { |pat| fb =~ pat } != []
        # accept_pattern on this directory
        if File.file?(File.join(dir, f)) &&
          accept_pattern.is_a?(Regexp) && f.match(accept_pattern).nil?
          next
        end
        files2 << f
      end
      (files - files2). each do |f|
        puts "WARNING: excluded file: #{f}"
      end
      files2
    end

    def install_files(src, list, dest, mode)
      run "install -d #{dest}"
      list.each do |fname|
        if File::directory?(src + '/' + fname)
          run "install -d #{dest + '/' + fname}"
        else
          run "install -m#{mode} #{src + '/' + fname} #{dest + '/' + fname}"
        end
      end
    end

    def destdir_for(package)
      File.expand_path(File.join('debian', package))
    end

    def update_shebangs(package)
      rubyver = DEFAULT_RUBY_VERSION
      ruby_binary = SUPPORTED_RUBY_VERSIONS[rubyver] || SUPPORTED_RUBY_VERSIONS[DEFAULT_RUBY_VERSION]
      Dir.glob(File.join(destdir_for(package), @bindir, '*')).each do |path|
        puts "Rewriting shebang line of #{path}" if @verbose
        atomic_rewrite(path) do |input, output|
          old = input.gets # discard
          output.puts "#!#{ruby_binary}"
          unless old =~ /#!/
            output.puts old
          end
          output.print input.read
        end
      end
    end

    def atomic_rewrite(path, &block)
      tmpfile = path + '.tmp'
      begin
        File.open(tmpfile, 'wb') do |output|
          File.open(path, 'rb') do |input|
            yield(input, output)
          end
        end
        File.rename tmpfile, path
      ensure
        File.unlink tmpfile if File.exist?(tmpfile)
      end
    end

    def packages
      @packages ||= `dh_listpackages`.split
    end

    def run_make_clean_on_extensions
      if metadata.has_native_extensions?
        metadata.native_extensions.each do |extension|
          extension_dir = File.dirname(extension)
          if File.exists?(File.join(extension_dir, 'Makefile'))
            puts "Running 'make distclean || make clean' in #{extension_dir}..."
            Dir.chdir(extension_dir) do
              run 'make distclean || make clean'
            end
          end
        end
      end
    end
  end
end
