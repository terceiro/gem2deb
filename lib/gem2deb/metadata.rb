# Copyright © 2011, Antonio Terceiro <terceiro@softwarelivre.org>
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

require 'rubygems'
require 'rubygems/specification'
require 'tempfile'
require 'time'
require 'yaml'

require 'gem2deb/package_name_mapping'

module Gem2Deb
  class Metadata

    attr_reader :gemspec
    attr_reader :source_dir
    attr_reader :root

    def initialize(root)
      @gemspec = nil
      @source_dir = File.expand_path(root)
      @root = root
      Dir.chdir(source_dir) do
        load_gemspec
      end
      populate_gemspec_fields
      sort_filenames
    end

    def has_native_extensions?
      native_extensions.size > 0
    end

    def native_extensions
      @native_extensions ||=
        if gemspec
          gemspec.extensions
        else
          Dir.chdir(source_dir) do
            list = []
            list += Dir.glob('**/extconf.rb')
            list += Dir.glob('ext/**/{configure,Rakefile}')
            list
          end
        end.map { |ext| File.join(root, ext) }
    end

    def name
      @name ||= gemspec && gemspec.name || read_name_from(source_dir)
    end

    def version
      @version ||= gemspec && gemspec.version.to_s || read_version_from(source_dir) || '0.1.0~FIXME'
    end

    def homepage
      gemspec && gemspec.homepage
    end

    def email
      gemspec && gemspec.email
    end

    def short_description
      gemspec && gemspec.summary
    end

    def long_description
      gemspec && gemspec.description
    end

    def dependencies
      gemspec ? gemspec.dependencies : []
    end

    def test_files
      gemspec ? gemspec.test_files.select { |filename| filename =~ /\.rb$/ } : []
    end

    def bindir
      (gemspec && gemspec.bindir.is_a?(String)) ? gemspec.bindir : 'bin'
    end

    def executables
      if gemspec
        if gemspec.executables.empty?
          nil
        else
          gemspec.executables
        end
      else
        Dir.glob(File.join(root, 'bin', '*')).map { |f| File.basename(f) }
      end
    end

    def get_debian_dependencies(global = true)
      calculate_debian_dependencies!(global)
    end

    protected

    def load_gemspec
      if File.exist?('debian/gemspec')
        if File.symlink?('debian/gemspec')
          path = File.expand_path(File.readlink('debian/gemspec'), 'debian')
          @gemspec = Gem::Specification.load(path)
        else
          @gemspec = Gem::Specification.load('debian/gemspec')
        end
      elsif File.exist?('metadata.yml')
        @gemspec = YAML.load_file('metadata.yml')
      elsif ENV['DH_RUBY_GEMSPEC']
        @gemspec = Gem::Specification.load(ENV['DH_RUBY_GEMSPEC'])
      else
        gemspec_files = Dir.glob('*.gemspec')
        if gemspec_files.size == 1
          @gemspec = load_modified_gemspec(gemspec_files.first)
          if @gemspec.nil?
            @gemspec = Gem::Specification.load(gemspec_files.first)
          end
          if @gemspec.nil?
            raise "E: cannot load gemspec #{gemspec_files.first}"
          end
        else
          unless gemspec_files.empty?
            raise "More than one .gemspec file in this directory: #{gemspec_files.join(', ')}"
          end
        end
      end
    end

    GIT_USAGE_MODIFIERS = {
      /\.files\s*=\s*`[^`]*git\s+ls-files[^`]*`\.split(\([^)]*\))?/ => '.files = ((Dir["**/*"] - Dir["debian/**/*"] - Dir["*.gemspec.gem2deb"]).select { |f| !File.directory?(f) })',
      /\.test_files\s*=\s*`[^`]*git\s+ls-files[^`]*`\.split(\([^)]*\))?/ => '.test_files = []',
      /(\w+)\.executables\s*=\s*`[^`]*git\s+ls-files[^`]*`\.split(\([^)]*\))?/ => '\1.executables = Dir[\1.bindir + "/*"]',
    }

    def load_modified_gemspec(original_gemspec_path)
      gemspec_text = File.read(original_gemspec_path)

      modified_gemspec = original_gemspec_path + '.gem2deb'
      GIT_USAGE_MODIFIERS.each do |find,replacement|
        gemspec_text.gsub!(find, replacement)
      end

      File.open(modified_gemspec, 'w') do |f|
        f.puts(gemspec_text)
      end

      spec = Gem::Specification.load(modified_gemspec)

      FileUtils.rm_f(modified_gemspec)

      spec
    end

    def populate_gemspec_fields
      return unless @gemspec
      if File.exist?('debian/changelog')
        @gemspec.date = Date.parse(`dpkg-parsechangelog -SDate`.strip)
      end
      if @gemspec.respond_to?(:rubyforge_project) # ruby2.5 and earlier
        # This field is deprecated in ruby2.7, and ignored by it.
        @gemspec.rubyforge_project = nil
      end
    end

    def sort_filenames
      # sort all filename lists in case they are generated in an unsorted way,
      # usually by `find` or some other unstable-sorting command.
      if @gemspec
        @gemspec.executables.sort!
        @gemspec.extensions.sort!
        @gemspec.extra_rdoc_files.sort!
        @gemspec.files.sort!
        @gemspec.require_paths.sort!
        @gemspec.test_files.sort!
      end
    end

    # FIXME duplicated logic (see below)
    def read_name_from(directory)
      return nil if directory.nil?
      basename = File.basename(directory)
      if basename =~ /^(.*)-([0-9.]+)$/
        $1
      else
        basename
      end
    end

    # FIXME duplicated logic (see above)
    def read_version_from(directory)
      return nil if directory.nil?
      basename = File.basename(directory)
      if basename =~ /^(.*)-([0-9.]+)$/
        $2
      else
        nil
      end
    end

    EPOCH = {
      # rails
      "ruby-actioncable"   => "2",
      "ruby-actionmailbox" => "2",
      "ruby-actionmailer"  => "2",
      "ruby-actionpack"    => "2",
      "ruby-actiontext"    => "2",
      "ruby-actionview"    => "2",
      "ruby-activejob"     => "2",
      "ruby-activemodel"   => "2",
      "ruby-activerecord"  => "2",
      "ruby-activestorage" => "2",
      "ruby-activesupport" => "2",
      "ruby-rails"         => "2",
      "ruby-railties"      => "2",
    }

    def calculate_debian_dependencies!(global = true)
      gem_to_package = Gem2Deb::PackageNameMapping.new(global)
      result = []
      if executables && executables.size > 0
        result << 'ruby'
      end
      dependencies.select do |dep|
        dep.type == :runtime
      end.each do |dep|
        dependency = gem_to_package[dep.name]
        version = dep.requirement.to_s
        if version == '>= 0'
          result << dependency
        else
          dep.requirements_list.each do |spec|
            op, v = spec.split
            if EPOCH.has_key?(dependency)
              v = EPOCH[dependency] + ":" + v
            end
            newop = {
              "~>" => ">=",
              ">" => ">>",
              "<" => "<<",
              "=" => ">=",
            }[op] || op
            result << ('%s (%s %s)' % [dependency, newop, v])
          end
        end
      end
      result
    end

  end
end
