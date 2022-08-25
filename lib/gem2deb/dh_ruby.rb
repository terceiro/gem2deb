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
require 'gem2deb/source'
require 'find'
require 'fileutils'

module Gem2Deb

  class DhRuby

    include Gem2Deb

    attr_accessor :verbose
    attr_accessor :installer_class

    class LegacyStrategy
      attr_reader :dh_ruby
      def initialize(dh_ruby)
        @dh_ruby = dh_ruby
      end

      def clean
        # nothing
      end

      def build
        # nothing
      end

      def test
        # nothing
      end

      def install(dh_auto_install_destdir)
        installers.each do |installer|
          installer.destdir_base = destdir_for(installer.binary_package, dh_auto_install_destdir)
          installer.build
          installer.install
        end
        run_tests
      end

      protected

      def installers
        dh_ruby.send(:installers)
      end

      def destdir_for(package, destdir)
        dh_ruby.send(:destdir_for, package, destdir)
      end

      def run_tests
        dh_ruby.send(:run_tests)
      end
    end

    class DebhelperCompat14Strategy < LegacyStrategy
      def clean
        FileUtils::Verbose.rm_rf dh_ruby.build_dir
      end

      def build
        installers.each do |installer|
          installer.destdir_base = destdir_for(installer.binary_package, nil)
          installer.build
        end
      end

      def test
        run_tests
      end

      def install(dh_auto_install_destdir)
        # copy from build dir into debian/
        Dir[dh_ruby.build_dir + "/*"].each do |pkg|
          FileUtils::Verbose.cp_r pkg, "debian"
        end
        installers.each do |installer|
          installer.destdir_base = destdir_for(installer.binary_package, dh_auto_install_destdir)
          installer.install
        end
      end
    end

    def initialize
      @verbose = true
      @skip_checks = nil
      @installer_class = Gem2Deb::Installer
      @source = Gem2Deb::Source.new
      @strategy =
        if @source.debhelper_compat >= 14
          DebhelperCompat14Strategy.new(self)
        else
          LegacyStrategy.new(self)
        end
    end

    def clean
      check_source_package

      make.clean

      installers.each do |installer|
        installer.clean
      end

      @strategy.clean
    end

    def configure
    end

    def build_dir
      @source.build_dir
    end

    def build
      make.build

      @strategy.build
    end

    def test
      @strategy.test
    end

    if File.exist? File.expand_path(File.join(File.dirname(__FILE__),'../../bin','gem2deb-test-runner'))
      TEST_RUNNER = File.expand_path(File.join(File.dirname(__FILE__),'../../bin','gem2deb-test-runner'))
    else
      TEST_RUNNER = "/usr/bin/gem2deb-test-runner"
    end

    def install(argv)
      dh_auto_install_destdir = argv.first

      make.install(destdir_for(@source.packages.first[:binary_package], dh_auto_install_destdir))

      ruby_versions.each do |version|
        if !SUPPORTED_RUBY_VERSIONS.include?(version)
          puts "E: #{version} is not supported by gem2deb anymore"
          exit(1)
        end
      end

      @strategy.install(dh_auto_install_destdir)

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
          puts "DEB_BUILD_OPTIONS includes nocheck, skipping all checks (test suite etc)." if @verbose
          @skip_checks = true
        else
          @skip_checks = false
        end
      end
      @skip_checks
    end

    def installers
      @installers ||=
        begin
          @source.packages.map do |package|
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

    def check_source_package
      if !File.readlines('debian/control').grep(/^XS-Ruby-Versions: /).empty?
        puts "W: XS-Ruby-Versions is deprecated, and will be ignored"
      end
    end

    def ruby_versions
      @ruby_versions ||= SUPPORTED_RUBY_VERSIONS.keys
    end

    def make
      @make ||= Gem2Deb::Make.new
    end

    def destdir_for(binary_package, dh_auto_install_destdir)
      if ENV['DH_RUBY_USE_DH_AUTO_INSTALL_DESTDIR']
        dh_auto_install_destdir
      else
        File.join(build_dir, binary_package.to_s)
      end
    end

  end
end
