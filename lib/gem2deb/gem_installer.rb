# Copyright © 2015, Antonio Terceiro <terceiro@debian.org>
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
require 'tmpdir'

module Gem2Deb

  class GemInstaller < Installer

    def self.get_list(name, obsolete_msg = nil)
      if ENV.has_key?(name) && obsolete_msg
        $stderr.puts("W: #{obsolete_msg}")
      end
      ENV.fetch(name, '').split
    end

    INSTALL_EXCLUDE_LIST = %w[
      bin/console
      bin/setup
      coverage/*
      debian/*
      examples/*
      features/*
      gemfiles/*
      doc/*
      man/*
      spec/*
      test/*
      tests/*
    ] + get_list('DH_RUBY_GEM_INSTALL_EXCLUDE') + get_list('DH_RUBY_GEM_INSTALL_BLACKLIST_APPEND', 'DH_RUBY_GEM_INSTALL_BLACKLIST_APPEND is deprecated, please use DH_RUBY_GEM_INSTALL_EXCLUDE instead (needs gem2deb >= 1.6~)')

    INSTALL_INCLUDE_LIST = %w[
      VERSION*
    ] + get_list('DH_RUBY_GEM_INSTALL_INCLUDE') + get_list('DH_RUBY_GEM_INSTALL_WHITELIST_APPEND is deprecated, please use DH_RUBY_GEM_INSTALL_INCLUDE instead (needs gem2deb >= 1.6~)')

    class NoGemspec < Exception
      def initialize(root)
        super("No gemspec found at #{root}")
      end
    end

    protected

    def include_list
      INSTALL_INCLUDE_LIST
    end

    def exclude_list
      INSTALL_EXCLUDE_LIST
    end

    def install_files_and_build_extensions
      done = false

      ruby_versions.each do |rubyver|
        if done && !metadata.has_native_extensions?
          break
        end

        ruby = SUPPORTED_RUBY_VERSIONS[rubyver]
        tmpdir = Dir.mktmpdir

        gemspec_data = load_gemspec_data!

        # don't install any test files
        gemspec_data.test_files = []

        # remove unwanted files and directories
        if gemspec_data.files.empty?
          gemspec_data.files = Dir['**/*']
        end
        gemspec_data.files.reject! do |entry|
          if include_list.any? { |incl| File.fnmatch(incl, entry) }
            false # included, don't reject
          else
            if !entry.index('/')
              true # exclude all top-level files by default
            else
              # reject if excluded
              exclude_list.any? { |exclude| File.fnmatch(exclude, entry) }
            end
          end
        end

        gemspec_data.executables.reject! do |prog|
          ['console', 'setup'].include?(prog)
        end

        gemspec_data.extra_rdoc_files = []

        # write modified gemspec at temporary directory
        gemspec = File.join(tmpdir, 'gemspec')
        File.open(gemspec, 'w') do |f|
          f.write(gemspec_data.to_ruby)
        end

        # build .gem
        Dir.chdir(root) do
          run_gem(ruby, 'build', gemspec)
          FileUtils.mv(Dir.glob('*.gem').first, tmpdir)
        end

        # install .gem
        ENV['make'] = make_cmd
        gempkg = Dir.glob(File.join(tmpdir, '*.gem')).first
        target_dir = rubygems_integration_target(rubyver)
        run_gem(
          ruby,
          'install',
          '--local',
          '--verbose',
          '--no-document',
          '--ignore-dependencies',
          '--install-dir', File.join(destdir_base, target_dir),
          gempkg
        )

        # Install binaries to /usr/bin
        programs = Dir.glob(File.join(destdir_base, target_dir, 'bin/*'))
        if !programs.empty?
          bindir = File.join(destdir_base, 'usr/bin')
          FileUtils::Verbose.mkdir_p bindir
          programs.each do |prog|
            FileUtils::Verbose.mv(prog, bindir)
          end
        end


        FileUtils::Verbose.cd(File.join(destdir_base, target_dir)) do
          %w[
          bin
          build_info
          cache
          doc
          ].each do |dir|
            FileUtils::Verbose.rm_rf(dir)
          end

          if metadata.has_native_extensions?
            run 'find', 'extensions', '-name', 'mkmf.log', '-delete'
            run 'find', 'extensions', '-name', 'gem_make.out', '-delete'
          else
            FileUtils::Verbose.rm_rf('extensions')
          end

          # remove empty plugins/ directory
          if Dir.exists?('plugins') && Dir.empty?('plugins')
              FileUtils::Verbose.rmdir('plugins')
          end

          FileUtils::Verbose.cd(File.join('gems', "#{metadata.name}-#{metadata.version}")) do
            # remove source of compiled extensions
            gemspec_data.extensions.each do |ext|
              FileUtils::Verbose.rm_rf(File.dirname(ext))
            end

            # remove duplicated *.so files from lib; they are already installed
            # to extensions/ in the top level
            FileUtils::Verbose.rm_f Dir.glob('lib/**/*.so')

            # Fix permissions of lib/**/*.rb
            # sometime upstream trees have .rb files with the executable bit set
            FileUtils::Verbose.chmod(0644, Dir['lib/**/*.rb'])

            # remove empty directories inside lib/
            if File.directory?('lib')
              run 'find', 'lib/', '-type', 'd', '-empty', '-delete'
            end

            # remove empty directories inside ext/
            if File.directory?('ext')
              run 'find', 'ext/', '-type', 'd', '-empty', '-delete'
            end
          end
        end

        # remove tmpdir
        FileUtils.rm_rf(tmpdir)

        done = true
      end
    end

    def install_gemspec
      # noop; regular installation already installs a gemspec
    end

    def rubygems_integration_target(rubyver)
      if metadata.has_native_extensions?
        api_version = Gem2Deb::RUBY_API_VERSION[rubyver]
        "/usr/lib/#{host_arch}/rubygems-integration/#{api_version}"
      else
        "/usr/share/rubygems-integration/all"
      end
    end

    def run_gem(ruby, command, *args)
      maybe_crossbuild(ruby) do
        run(ruby, '-S', 'gem', command, '--config-file', '/dev/null', '--verbose', *args)
      end
    end

    def load_gemspec_data!
      if metadata.gemspec
        metadata.gemspec
      else
        raise NoGemspec.new(root)
      end
    end

  end

end
