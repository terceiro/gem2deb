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

    include Gem2Deb

    attr_accessor :verbose

    attr_reader :metadata

    def initialize
      @verbose = true
      @bindir = '/usr/bin'
      @metadata = Gem2Deb::Metadata.new('.')
    end
    
    def clean
      puts "Entering dh_ruby --clean" if @verbose
      run_make_clean_on_extensions
    end

    def configure
      # puts "Entering dh_ruby --configure" if @verbose
    end

    def build
      # puts "Entering dh_ruby --build" if @verbose
    end

    def test
      # puts "Entering dh_ruby --test" if @verbose
    end

    EXTENSION_BUILDER = File.expand_path(File.join(File.dirname(__FILE__),'extension_builder.rb'))
    LIBDIR = File.expand_path(File.join(File.dirname(__FILE__), '..'))

    def install(argv)
      puts "Entering dh_ruby --install" if @verbose

      packages_to_install_programs_in.each do |package|
        install_files('bin', find_files('bin'), File.join(destdir_for(package), @bindir),             755) if File::directory?('bin')
      end

      packages_to_install_libraries_in.each do |package|
        install_files('lib', find_files('lib'), File.join(destdir_for(package), libdir_for(package)), 644) if File::directory?('lib')
      end

      packages.each do |package|
        # handle extensions
        rubyver = ruby_version_for(package)
        if rubyver == 'ruby'
          if packages.size == 1 # pure-Ruby lib
            SUPPORTED_RUBY_VERSIONS.keys.each do |ver|
              run_tests(ver)
            end
          end
        else
          if metadata.has_native_extensions?
            if not SUPPORTED_RUBY_VERSIONS.has_key?(rubyver)
              puts "Unknown Ruby version: #{rubyver}"
              exit(1)
            end
            puts "Building extension for #{rubyver} ..." if @verbose
            run("#{SUPPORTED_RUBY_VERSIONS[rubyver]} -I#{LIBDIR} #{EXTENSION_BUILDER} #{package}")
          end
          run_tests(rubyver)
        end

        # Update shebang lines of installed programs
        update_shebangs(package)
      end

      # FIXME after install, check for require 'rubygems' and other stupid things, and
      #       issue warnings

      check_rubygems
    end

    protected

    def check_rubygems
      return if ENV['DEB_BUILD_OPTIONS'] and ENV['DEB_BUILD_OPTIONS'].split(' ').include?('nocheck')
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
      if ENV['DEB_BUILD_OPTIONS'] and ENV['DEB_BUILD_OPTIONS'].split(' ').include?('nocheck')
        puts "DEB_BUILD_OPTIONS include nocheck, skipping test suite."
        return
      end
      if File::exists?('debian/ruby-test-files.yaml')
        puts "Running tests for #{rubyver} using gem2deb test runner and debian/ruby-test-files.yaml..."
        testrunner = File.join(File.dirname(__FILE__),'testrunner.rb')
        cmd = "#{SUPPORTED_RUBY_VERSIONS[rubyver]} #{testrunner}"
        puts(cmd) if $VERBOSE
        system(cmd)
      elsif File::exists?('debian/ruby-tests.rb')
        puts "Running tests for #{rubyver} using debian/ruby-tests.rb..."
        cmd = "#{SUPPORTED_RUBY_VERSIONS[rubyver]} -Ilib debian/ruby-tests.rb"
        puts(cmd) if $VERBOSE
        system(cmd)
      else
        puts "Running tests for #{rubyver}: found no way to run a test suite!"
      end
      if $? && ($? >> 8) > 0
        handle_test_failure(rubyver)
      end
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

    def ruby_version_for(package)
      if package =~ /^(ruby[^-]*)/
        $1
      else
        'ruby'
      end
    end

    def destdir_for(package)
      File.expand_path(File.join('debian', package))
    end

    def update_shebangs(package)
      rubyver = ruby_version_for(package)
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

    def packages_to_install_libraries_in
      if single_package?
        packages
      else
        if has_common_package?
          common_packages
        else
          native_packages
        end
      end
    end

    def packages_to_install_programs_in
      if single_package?
        packages
      else
        if has_common_package?
          common_packages
        else
          packages.first
        end
      end
    end

    def single_package?
      packages.size == 1
    end

    def has_common_package?
      common_packages.size > 0
    end

    def common_packages
      @common_packages ||= packages.grep(/ruby-.*-common/)
    end

    def native_packages
      @native_packages ||= packages.select { |pkg| ruby_version_for(pkg) != 'ruby' }
    end

    def libdir_for(package)
      case ruby_version_for(package)
      when 'ruby1.8'
        '/usr/lib/ruby/vendor_ruby/1.8'
      when 'ruby1.9.1'
        '/usr/lib/ruby/vendor_ruby/1.9.1'
      else
        '/usr/lib/ruby/vendor_ruby'
      end
    end

    def run_make_clean_on_extensions
      if metadata.has_native_extensions?
        metadata.native_extensions.each do |extension|
          extension_dir = File.dirname(extension)
          if File.exists?(File.join(extension_dir, 'Makefile'))
            puts "Running 'make clean' in #{extension_dir}..."
            Dir.chdir(extension_dir) do
              run 'make clean'
            end
          end
        end
      end
    end

  end
end
