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
require 'yaml'

module Gem2Deb
  class Metadata

    attr_reader :gemspec

    attr_reader :native_extensions

    def initialize(directory)
      Dir.chdir(directory) do
        load_gemspec
        if gemspec
          initialize_from_gemspec
        else
          initialize_without_gemspec
        end
      end
    end

    def has_native_extensions?
      native_extensions.size > 0
    end

    def homepage
      gemspec && gemspec.homepage
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
      gemspec ? gemspec.test_files : []
    end

    protected

    def load_gemspec
      if File.exists?('metadata.yml')
        @gemspec = YAML.load_file('metadata.yml')
      elsif ENV['DH_RUBY_GEMSPEC']
        @gemspec = Gem::Specification.load(ENV['DH_RUBY_GEMSPEC'])
      else
        gemspec_files = Dir.glob('*.gemspec')
        if gemspec_files.size == 1
          @gemspec = Gem::Specification.load(gemspec_files.first)
        else
          unless gemspec_files.empty?
            raise "More than one .gemspec file in this directory: #{gemspec_files.join(', ')}"
          end
        end
      end
    end

    def initialize_from_gemspec
      @native_extensions = gemspec.extensions
    end

    def initialize_without_gemspec
      @native_extensions = Dir.glob('**/extconf.rb') + Dir.glob('ext/**/{configure,Rakefile}')
    end

  end
end
