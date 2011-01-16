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
# dh_ruby must update the shebang after installation of binaries, to point to
# the default ruby version
#
# dh_ruby should do some checking (lintian-like) of ruby-specific stuff. For example,
# it could search for "require 'rubygems'" in libraries, and display warnings
#
# dh_ruby could generate rdoc (not sure if we want this)

require 'gem2deb'
require 'find'

module Gem2Deb

  class DhRuby

    SUPPORTED_RUBY_VERSIONS = {
      #name             Ruby binary          
      #---------------  -------------------
      'ruby1.8'   => '/usr/bin/ruby1.8',  
      'ruby1.9.1' => '/usr/bin/ruby1.9.1',
    }

    def initialize
      @verbose = true
      @bindir = '/usr/bin'
      @prefix = nil
      @mandir = '/usr/share/man'
      @libdir = '/usr/lib/ruby/vendor_ruby'
      @gemmandirs = (1..8).collect {|section | "man/man#{section}" }
      @man_accept_pattern = /\.([1-8])$/
      # FIXME handle multi-version rubies (libs that require patches for some versions)
      if File::exists?('debian/dh_ruby.overrides')
         # FIXME
      end
    end
    
    def clean
      puts "Entering dh_ruby --clean" if @verbose
      if File::directory?('ext')
        Find::find('ext') do |f|
          if File::basename(f) == 'Makefile'
          puts "Running 'make clean' in #{File::dirname(f)}..."
          Dir::chdir(File::dirname(f))
            system("make clean")
          end
        end
      end
    end

    def configure
      # puts "Entering dh_ruby --configure" if @verbose
    end

    def build
      # puts "Entering dh_ruby --build" if @verbose
    end

    def test
      # puts "Entering dh_ruby --test" if @verbose
      # FIXME detect and run test suite
    end

    def install
      @prefix = ARGV[0]
      puts "Entering dh_ruby --install" if @verbose

      install_files('bin', find_files('bin'), @bindir,          755) if File::directory?('bin')
      install_files('lib', find_files('lib'), @libdir,  644) if File::directory?('lib')

      # handle extensions
      if File::directory?('ext')
        `dh_listpackages`.each_line do |pkg|
          pkg.chomp!
          rubyver = pkg.split('-')[0]
          next if rubyver == 'ruby' # common package, nothing to do
          if not SUPPORTED_RUBY_VERSIONS.has_key?(rubyver)
            puts "Unknown Ruby version: #{rubyver}"
            exit(1)
          end
          extension_builder = File.join(File.dirname(__FILE__),'extension_builder.rb')
          puts "Building extension for #{rubyver} ..."
          run("#{SUPPORTED_RUBY_VERSIONS[rubyver]} #{extension_builder} #{pkg}")
          run_tests(rubyver)
        end
      else
        ['ruby1.8', 'ruby1.9.1'].each do |rubyver|
          run_tests(rubyver)
        end
      end

      # manpages
      # FIXME use dh_installman. Maybe to be moved to dh-make-ruby?
      if File::directory?('man')
        # man/man1/apps.1 scheme
        if @gemmandirs.any? {|m| File::directory?(m) }
          install_files('man', find_files('man', @man_accept_pattern), @mandir, 644)
        else
          # man/apps.1 scheme
          Dir.glob("man/*.[1-8]").each do |man_file|
            match = man_file.match(@man_accept_pattern)
            if match && (section = match.captures.first)
              install_files('man', [File.basename(man_file)], "#{@mandir}/man#{section}", 644)
            end
          end
        end
      end
      # FIXME after install, update shebang of binaries to default ruby version
      # FIXME after install, check for require 'rubygems' and other stupid things, and
      #       issue warnings
    end

    protected

    def run_tests(rubyver)
      if ENV['DEB_BUILD_OPTIONS'] and ENV['DEB_BUILD_OPTIONS'].split(' ').include?('nocheck')
        puts "DEB_BUILD_OPTIONS include nocheck, skipping test suite."
        return
      end
      if File::exists?('debian/ruby-test-files.yaml')
        puts "Running tests for #{rubyver} using gem2deb test runner and debian/ruby-test-files.yaml..."
        testrunner = File.join(File.dirname(__FILE__),'testrunner.rb')
        run("#{SUPPORTED_RUBY_VERSIONS[rubyver]} #{testrunner}")
      elsif File::exists?('debian/ruby-tests.rb')
        puts "Running tests for #{rubyver} using debian/ruby-tests.rb..."
        run("#{SUPPORTED_RUBY_VERSIONS[rubyver]} -Ilib debian/ruby-tests.rb")
      else
        puts "Running tests for #{rubyver}: found no way to run a test suite!"
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
      run "install -d #{@prefix + '/' + dest}"
      list.each do |fname|
        if File::directory?(src + '/' + fname)
          run "install -d #{@prefix + '/' + dest + '/' + fname}"
        else
          run "install -m#{mode} #{src + '/' + fname} #{@prefix + '/' + dest + '/' + fname}"
        end
      end
    end

  end
end
