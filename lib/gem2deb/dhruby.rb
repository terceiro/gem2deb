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

    COMMON_LIBDIR = '/usr/lib/ruby/vendor_ruby'

    attr_accessor :verbose

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
      puts "Entering dh_ruby --configure" if @verbose
    end

    def build
      puts "Entering dh_ruby --build" if @verbose
    end

    def test
      puts "Entering dh_ruby --test" if @verbose
      # FIXME detect and run test suite
    end

    def install(argv)
      @prefix = argv.first
      puts "Entering dh_ruby --install" if @verbose

      install_files('bin', find_files('bin'), @bindir,          755) if File::directory?('bin')
      install_files('lib', find_files('lib'), @libdir,  644) if File::directory?('lib')

      packages = `dh_listpackages`.split.map(&:strip)

      # handle extensions
      if File::directory?('ext')
        packages do |pkg|
          pkg.chomp!
          rubyver = ruby_version_for(pkg)
          next if rubyver == 'ruby' # common package, nothing to do
          if not SUPPORTED_RUBY_VERSIONS.has_key?(rubyver)
            puts "Unknown Ruby version: #{rubyver}"
            exit(1)
          end
          extension_builder = File.join(File.dirname(__FILE__),'extension_builder.rb')
          puts "Building extension for #{rubyver} ..."
          run("#{SUPPORTED_RUBY_VERSIONS[rubyver]} #{extension_builder} #{pkg}")
        end
      end

      # Update shebang lines of installed programs
      packages.each do |pkg|
        update_shebangs(pkg)
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

      # FIXME after install, check for require 'rubygems' and other stupid things, and
      #       issue warnings
    end

    protected

    JUNK_FILES = %w( core RCSLOG tags TAGS .make.state .nse_depinfo )
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

    def ruby_version_for(package)
      package.split('-')[0]
    end

    def update_shebangs(package)
      rubyver = ruby_version_for(package)
      ruby_binary = SUPPORTED_RUBY_VERSIONS[rubyver] || SUPPORTED_RUBY_VERSIONS[DEFAULT_RUBY_VERSION]
      Dir.glob(File.join(@prefix, @bindir, '*')).each do |path|
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

  end
end
