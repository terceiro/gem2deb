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
# Different installation schemes:
# - the most common one is "pure ruby, with common code for all interpreters". In
#   that case, we just install libs to /usr/lib/ruby/vendor_ruby.
#   Only one binary package, named (for libs): ruby-foo
# - the other case is "different code for different interpreters" (because the code
#   needs changes for some interpreters, or because it includes native libs). In that
#   case, we need one binary package per interpreter, and we install to
#   /usr/lib/ruby/vendor_ruby/<VERSION>/
#   One binary package per interpreter, named <interpreter>-foo 
#   (interpreter=ruby1.8,ruby1.9.1,jruby,...)
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

    def initialize
      @verbose = true
      @bindir = '/usr/bin'
      @libdir = '/usr/lib/ruby/vendor_ruby'
      @prefix = nil
      # FIXME datadir
      @mandir = '/usr/share/man'
      @gemmandirs = (1..8).collect {|section | "man/man#{section}" }
      # FIXME handle multi-version rubies (libs that require patches for some versions)
      if File::exists?('debian/dh_ruby.overrides')
         # FIXME
      end
    end
    
    def clean
      puts "Entering dh_ruby --clean" if @verbose
      # FIXME run make clean in ext/
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

    def install
      @prefix = ARGV[0]
      package = File::basename(@prefix)
      puts "Entering dh_ruby --install (for #{package})" if @verbose

      if File::directory?('ext')
        puts "This library has an 'ext' dir. We don't know how to deal with it yet."
        # FIXME need to run extconf and make.
        exit(1)
      end
      if File::directory?('data') or File::directory?('conf')
        # FIXME
        puts "We don't know how to deal with conf and data dirs yet."
        exit(1)
      end
      install_files('bin', find_files('bin'), @bindir, 755) if File::directory?('bin')
      install_files('lib', find_files('lib'), @libdir, 644) if File::directory?('lib')

      # manpages
      if File::directory?('man')
        # man/man1/apps.1 scheme
        if @gemmandirs.any? {|m| File::directory?(m) }
          install_files('man', find_files('man'), @mandir, 644)
        else
          # man/apps.1 scheme
          Dir.glob("man/*.[1-8]").each do |man_file|
            match = man_file.match(/.*\.(\d)$/)
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

    JUNK_FILES = %w( core RCSLOG tags TAGS .make.state .nse_depinfo )
    HOOK_FILES = %w( pre-%s post-%s pre-%s.rb post-%s.rb ).map {|fmt|
      %w( config setup install clean ).map {|t| sprintf(fmt, t) }
      }.flatten
    JUNK_PATTERNS = [ /^#/, /^\.#/, /^cvslog/, /^,/, /^\.del-*/, /\.olb$/,
        /~$/, /.(old|bak|BAK|orig|rej)$/, /^_\$/, /\$$/, /\.org$/, /\.in$/, /^\./ ]

    def find_files(dir)
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
