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
require 'yaml'
require 'rubygems/ext'
require 'gem2deb/metadata'
require 'fileutils'

module Gem2Deb
  class ExtensionBuilder

    include Gem2Deb

    attr_reader :root
    attr_reader :extension
    attr_reader :directory

    def initialize(root, extension)
      @root = root
      @extension = extension
      @directory = File.dirname(extension)
    end

    def clean
      Dir.chdir(directory) do
        if File.exist?('Makefile')
          run 'make clean'
        end
      end
    end

    def build_and_install(destdir)
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
        # override make environment variable to set V variable to 1 for verbose builds
        env_make_old = ENV['make']
        ENV['make'] ||= make_cmd

        # make sure RakeBuilder uses the correct path to rake
        env_rake_old = ENV['rake']
        ENV['rake'] = '/usr/bin/rake'

        target = File.expand_path(File.join(destdir, RbConfig::CONFIG['vendorarchdir']))
        FileUtils.mkdir_p(target)
        Dir.chdir(directory) do
          verbose = Gem.configuration.verbose
          # will make Rubygems builder send the output to the terminal in
          # real time
          Gem.configuration.verbose = 'YES'

          # Gem::Ext::*Builder.build() changed in Ruby 2.6.0.preview2.
          if Gem::Version.new(RUBY_VERSION) < Gem::Version.new('2.6.0')
            rubygems_builder.build(extension, '.', target, results)
          else
            rubygems_builder.build(extension, target, results)
          end

          puts results

          Gem.configuration.verbose = verbose
        end

        # handle mkmf.log being installed at the extension directory by
        # Rubygems on Ruby 2.1+
        mkmf_log = File.join(target, 'mkmf.log')
        if File.exist?(mkmf_log)
          run 'rm', '-f', mkmf_log
        end

      rescue Exception => e
        target = File.expand_path(File.join(destdir, RbConfig::CONFIG['vendorarchdir']))
        mkmf_log = File.join(target, 'mkmf.log')
        if File.exist?(mkmf_log)
          puts '~~~~~~~~~~~~~~~~~~~~~ ↓ mkmf.log ~~~~~~~~~~~~~~~~~~~~~'
          system('cat', mkmf_log)
          puts '~~~~~~~~~~~~~~~~~~~~~ ↑ mkmf.log ~~~~~~~~~~~~~~~~~~~~~'
        end
        raise e
      ensure
        ENV['make']=env_make_old
        ENV['rake']=env_rake_old
      end
    end

    def self.build_all_extensions(root, destdir)
      all_extensions(root).each do |extension|
        ext = new(root, extension)
        ext.clean
        ext.build_and_install(destdir)
      end
    end

    def self.all_extensions(root)
      @metadata ||= Gem2Deb::Metadata.new(root)
      @metadata.native_extensions
    end
  end
end

if $PROGRAM_NAME == __FILE__
  if ARGV.length == 2
    Gem2Deb::ExtensionBuilder.build_all_extensions(*ARGV)
  else
    puts "usage: #{File.basename($PROGRAM_NAME)} ROOT DESTDIR"
    exit(1)
  end
end
