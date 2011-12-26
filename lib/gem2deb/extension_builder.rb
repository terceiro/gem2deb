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

require 'gem2deb'
require 'gem2deb/yaml'
require 'rubygems/ext'
require 'gem2deb/metadata'

module Gem2Deb
  class ExtensionBuilder

    include Gem2Deb

    attr_reader :extension
    attr_reader :package
    attr_reader :directory

    def initialize(extension, pkg)
      @extension = extension
      @package = pkg
      @directory = File.dirname(extension)
    end

    def clean
      Dir.chdir(directory) do
        if File.exists?('Makefile')
          run 'make clean'
        end
      end
    end

    def build_and_install
      clean
      results = []
      rubygems_builder =
        case extension
        when /extconf/ then
          Gem::Ext::ExtConfBuilder
        when /configure/ then
          Gem::Ext::ConfigureBuilder
        when /rakefile/i, /mkrf_conf/i then
          Gem::Ext::RakeBuilder
        else
          puts "Cannot build extension '#{extension}'"
          exit(1)
        end
      begin
        target = File.expand_path(File.join('debian', package, RbConfig::CONFIG['vendorarchdir']))
        Dir.chdir(directory) do
          rubygems_builder.build(extension, '.', target, results)
          puts results
        end
      rescue Exception => e
        puts results
        raise e
      end
    end

    def self.build_all_extensions(package)
      all_extensions.each do |extension|
        ext = new(extension, package)
        ext.clean
        ext.build_and_install
      end
    end

    def self.all_extensions
      @metadata ||= Gem2Deb::Metadata.new('.')
      @metadata.native_extensions
    end
  end
end

if $PROGRAM_NAME == __FILE__
  if ARGV.length == 1
    Gem2Deb::ExtensionBuilder.build_all_extensions(ARGV.first)
  else
    puts "usage: #{File.basename($PROGRAM_NAME)} PKGNAME"
    exit(1)
  end
end
