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

require 'gem2deb'
require 'gem2deb/banner'
require 'gem2deb/installer'
require 'gem2deb/make'
require 'find'
require 'fileutils'

module Gem2Deb

  class DhRuby

    include Gem2Deb

    attr_accessor :verbose
    attr_accessor :installer_class

    def initialize
      @verbose = true
      @skip_checks = nil
      @installer_class = Gem2Deb::Installer
    end

    def clean
      puts "   dh_ruby --clean" if @verbose

      make.clean

      installers.each do |installer|
        installer.run_make_clean_on_extensions
      end
    end

    def configure
      # puts "   dh_ruby --configure" if @verbose
    end

    def build
      puts "   dh_ruby --build" if @verbose

      make.build
    end

    def test
      # puts "   dh_ruby --test" if @verbose
    end

    if File.exist? File.expand_path(File.join(File.dirname(__FILE__),'../../bin','gem2deb-test-runner'))
      TEST_RUNNER = File.expand_path(File.join(File.dirname(__FILE__),'../../bin','gem2deb-test-runner'))
    else
      TEST_RUNNER = "/usr/bin/gem2deb-test-runner"
    end

    def install(argv)
      puts "   dh_ruby --install" if @verbose

      dh_auto_install_destdir = argv.first

      make.install(destdir_for(packages.first[:binary_package], dh_auto_install_destdir))

      ruby_versions.each do |version|
        if !SUPPORTED_RUBY_VERSIONS.include?(version)
          puts "E: #{version} is not supported by gem2deb anymore"
          exit(1)
        end
      end

      installers.each do |installer|
        installer.destdir_base = destdir_for(installer.binary_package, dh_auto_install_destdir)
        installer.install_files_and_build_extensions
        installer.update_shebangs
      end

      installers.each do |installer|
        installer.install_substvars
        installer.install_gemspec
      end

      run_tests

      # FIXME remove this message after stretch
      if File.exists?('debian/require-rubygems.overrides')
        puts "W: debian/require-rubygems.overrides is obsolete, and is now ignored"
      end

      Gem2Deb::Banner.print 'dh_ruby --install finished'
    end

    protected # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

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
      if interactive
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

    def interactive
      STDIN.isatty && STDOUT.isatty && STDERR.isatty &&
        ENV['DEB_BUILD_OPTIONS'] &&
        ENV['DEB_BUILD_OPTIONS'].split.include?('dh_ruby_interactive')
    end

    def run_tests
      ruby_versions.each do |rubyver|
        run_tests_for_version(rubyver)
      end
    end

    def run_tests_for_version(rubyver)
      if skip_checks?
        return
      end

      begin
        run_ruby(SUPPORTED_RUBY_VERSIONS[rubyver], TEST_RUNNER)
      rescue Gem2Deb::CommandFailed
        handle_test_failure(rubyver)
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

    def packages
      @packages ||=
        begin
          packages = []
          multibinary = false
          File.readlines('debian/control').select do |line|
            if line =~ /^Package:\s*(\S*)\s*$/
              package = $1
              packages.push({ :binary_package => package })
            elsif line =~ /^X-DhRuby-Root:\s*(\S*)\s*$/
              root = $1
              if packages.last
                packages.last[:root] = root
              end
              multibinary = true
            end
          end
          if multibinary
            packages.select { |p| p[:root] }
          else
            package = packages.first
            package[:root] = '.'
            [package]
          end
        end
    end

    def installers
      @installers ||=
        begin
          packages.map do |package|
            installer_class.new(
              package[:binary_package],
              package[:root],
              ruby_versions
            ).tap do |installer|
              installer.verbose = self.verbose
            end
          end
        end
    end

    def ruby_versions
      @ruby_versions ||=
        begin
          # find ruby versions to build the package for.
          lines = File.readlines('debian/control').grep(/^XS-Ruby-Versions: /)
          if lines.empty?
            puts "No XS-Ruby-Versions: field found in source!" if @verbose
            exit(1)
          else
            list = lines.first.split[1..-1]
            if list.include?('all')
              SUPPORTED_RUBY_VERSIONS.keys
            else
              list
            end
          end
        end
    end

    def make
      @make ||= Gem2Deb::Make.new
    end

    def destdir_for(binary_package, dh_auto_install_destdir)
      if ENV['DH_RUBY_USE_DH_AUTO_INSTALL_DESTDIR']
        dh_auto_install_destdir
      else
        File.join('debian', binary_package.to_s)
      end
    end

  end
end
