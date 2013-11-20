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
require 'gem2deb/installer'
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
      puts "  Entering dh_ruby --clean" if @verbose

      installers.each do |installer|
        installer.run_make_clean_on_extensions
      end

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

    TEST_RUNNER = File.expand_path(File.join(File.dirname(__FILE__),'test_runner.rb'))

    def install(argv)
      puts "  Entering dh_ruby --install" if @verbose

      installers.each do |installer|
        installer.dh_auto_install_destdir = argv.first
        installer.install_files_and_build_extensions
        installer.update_shebangs
      end

      run_tests

      installers.each do |installer|
        installer.install_substvars
        installer.install_gemspec
        check_rubygems(installer)
      end

      puts "  Leaving dh_ruby --install" if @verbose
    end

    protected

    def check_rubygems(installer)
      if skip_checks?
        return
      end

      begin
        installer.check_rubygems
      rescue Gem2Deb::Installer::RequireRubygemsFound
        handle_test_failure("require-rubygems")
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

    def run_tests
      ruby_versions.each do |rubyver|
        run_tests_for_version(rubyver)
      end
    end

    def run_tests_for_version(rubyver)
      if skip_checks?
        return
      end

      run(SUPPORTED_RUBY_VERSIONS[rubyver], '-I' + LIBDIR, TEST_RUNNER)

      if $?.exitstatus != 0
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

  end
end
