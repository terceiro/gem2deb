# vim: ts=2 sw=2 expandtab
# -*- coding: utf-8 -*-
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
require 'yaml'
require 'gem2deb/metadata'
require 'gem2deb/test_runner'
require 'rubygems'
require 'fileutils'
require 'erb'
require 'date'

module Gem2Deb

  class DhMakeRuby

    include Gem2Deb

    EMAIL_REGEXP = /^(.*)\s+<(.*)>$/

    attr_accessor :gem_name

    attr_accessor :gem_version

    attr_accessor :metadata

    attr_reader :source_package_name

    def source_package_name=(value)
      @source_package_name = value.gsub('_', '-')
    end

    attr_accessor :binary_package

    attr_accessor :source_tarball_name

    attr_accessor :orig_tarball_name

    attr_accessor :orig_tarball_dir

    attr_accessor :ruby_versions

    attr_accessor :input_directory

    attr_accessor :do_wnpp_check

    def initialize(input, options = {})
      initialize_from_options(options)
      if File.directory?(input)
        initialize_from_directory(input)
      else
        initialize_from_tarball(input)
      end
    end

    def initialize_from_options(options)
      self.ruby_versions = 'all'
      options.each do |attr,value|
        self.send("#{attr}=", value)
      end
    end

    def initialize_from_directory(directory)
      self.input_directory = directory
      read_metadata(directory)
      self.gem_name = metadata.name
      self.gem_version = metadata.version
      self.source_package_name ||= gem_name_to_source_package_name(gem_name)
    end

    def initialize_from_tarball(tarball)
      self.source_tarball_name = File.basename(tarball)
      self.orig_tarball_dir = File.dirname(tarball)

      if source_tarball_name =~ /^(.*)_(.*).orig.tar.gz$/
        self.gem_name = $1
        self.gem_version = $2
        self.source_package_name ||= gem_name # assume orig.tar.gz was previously prepared and is already correct
        self.orig_tarball_name = source_tarball_name
      elsif source_tarball_name =~ /^(.*)-(.*).tar.gz$/
        self.gem_name = $1
        self.gem_version = $2
        self.source_package_name ||= gem_name_to_source_package_name(gem_name)
        self.orig_tarball_name = "#{source_package_name}_#{gem_version}.orig.tar.gz"
      else
        raise "Could not determine gem name and version from tarball #{source_tarball_name}"
      end
    end

    def gem_name_to_source_package_name(gem_name)
      'ruby-' + gem_name.gsub(/^ruby[-_]|[-_]ruby$/, '')
    end

    def gem_dirname
      [gem_name, gem_version].join('-')
    end

    def source_dirname
      [source_package_name, gem_version].join('-')
    end

    def homepage
      metadata.homepage
    end

    def short_description
      metadata.short_description
    end

    def long_description
      metadata.long_description
    end

    def build
      if input_directory
        build_in_directory(input_directory)
      else
        Dir.chdir(orig_tarball_dir) do
          create_orig_tarball
          extract
          initialize_from_directory(source_dirname)
          build_in_directory(source_dirname)
        end
      end
    end

    def build_in_directory(directory)
      Dir.chdir(directory) do
        read_upstream_source_info
        create_debian_boilerplates
        other_files
        test_suite
      end
    end
    
    def read_upstream_source_info
      read_metadata('.')
      initialize_binary_package
    end

    def read_metadata(directory)
      @metadata ||= Gem2Deb::Metadata.new(directory)
    end

    def initialize_binary_package
      self.binary_package = Package.new(source_package_name, metadata.has_native_extensions? ? 'any' : 'all')
      metadata.dependencies.each do |dependency|
        binary_package.gem_dependencies << dependency
      end
      binary_package
    end

    def buildpackage(source_only = false, check_build_deps = true)
      dpkg_buildpackage_opts = []
      dpkg_buildpackage_opts << '-S' if source_only
      dpkg_buildpackage_opts << '-d' unless check_build_deps

      Dir.chdir(source_dirname) do
        run('dpkg-buildpackage', '-us', '-uc', *dpkg_buildpackage_opts)
      end
    end

    def create_orig_tarball
      if source_package_name != orig_tarball_name && !File.exists?(orig_tarball_name)
        run('ln', '-s', source_tarball_name, orig_tarball_name)
      end
    end

    def extract
      run('tar', 'xzf', orig_tarball_name)
      if !File.directory?(gem_dirname)
        raise "Extracting did not create #{gem_dirname} directory."
      end
      if gem_dirname != source_dirname && !File.exists?(source_dirname)
        FileUtils.mv gem_dirname, source_dirname
      end
    end

    def wnpp_check
      `wnpp-check #{source_package_name}`
    end

    def itp_bug
      if do_wnpp_check && wnpp_check.length > 0
        wnpp_check.split(" ")[2].chomp(")")
      else
        "#nnnn"
      end
    end

    def write_if_missing(filename)
      unless File.exist? filename
        File.open(filename, 'w') { |f| yield f }
      end
    end

    def create_debian_boilerplates
      FileUtils.mkdir_p('debian')
      unless File.exists?('debian/changelog')
        run('dch', '--create', '--empty', '--package', source_package_name,
            '--newversion', "#{gem_version}-1",
            "Initial release (Closes: #{itp_bug})")
      end
      templates.each do |template|
        FileUtils.mkdir_p(template.directory)
        write_if_missing(template.filename) do |f|
          f.puts ERB.new(template.data, nil, '<>').result(binding)
        end
      end
      FileUtils.chmod 0755, 'debian/rules'
    end

    def templates
      @templates ||= Template.load_all
    end

    class Template
      attr_accessor :filename
      attr_accessor :data

      TEMPLATES_DIR = File.expand_path(File.join(File.dirname(__FILE__), 'dh_make_ruby', 'template'))

      def self.load_all
        template_files = Dir.chdir(TEMPLATES_DIR) { Dir.glob("**/*").select { |f| !File.directory?(f) } }
        template_files.map do |filename|
          template = Template.new(filename)
          template.data = File.read(File.join(TEMPLATES_DIR, filename))
          template
        end
      end

      def initialize(filename)
        self.filename = filename
        self.data = ''
      end

      def directory
        File.dirname(filename)
      end
    end

    ##
    # Try to find the maintainer from ENV
    # logic translated from perl in package « devscripts: /usr/bin/dch »
    #
    def maintainer
      debenv = {}
      # defaults
      debenv['DEBFULLNAME'] = ENV['DEBFULLNAME']
      debenv['DEBEMAIL'] = ENV['DEBEMAIL'] || ENV['EMAIL']

      # DEBEMAIL is like "Full Name <email@host>"
      # extract DEBFULLNAME from it
      if ENV['DEBEMAIL'] && ENV['DEBEMAIL'] =~ EMAIL_REGEXP
        debenv['DEBFULLNAME'] = $1 if ENV['DEBFULLNAME'].nil?
        debenv['DEBEMAIL'] = $2
      end
      # dont have DEBEMAIL nor DEBFULLNAME from ENV
      # try with EMAIL
      if ENV['DEBEMAIL'].nil? || ENV['DEBFULLNAME'].nil?
        if ENV['EMAIL'] && ENV['EMAIL'] =~ EMAIL_REGEXP
          debenv['DEBFULLNAME'] = $1 if ENV['DEBFULLNAME'].nil?
          debenv['DEBEMAIL'] = $2
        end
      end
      debenv
    end

    class Package
      attr_accessor :name
      attr_accessor :architecture
      def initialize(name, architecture = 'all')
        self.name = name
        self.architecture = architecture
      end
      def dependencies
        ['${shlibs:Depends}', '${misc:Depends}', 'ruby | ruby-interpreter' ]
      end
      def gem_dependencies
	@gem_dependencies ||= []
      end
    end

    def test_suite
      if !Gem2Deb::TestRunner.detect
        test_suite_rspec or test_suite_yaml or test_suite_rb
      end
    end

    def test_suite_rspec
      if File::directory?("spec")
        write_if_missing("debian/ruby-tests.rake") do |f|
          f.puts <<-EOF
# FIXME
# there's a spec/ directory in the upstream source.
# The recommended way to run the RSpec suite is via a rake task.
# The following commands are enough in many cases and can be adapted to other
# situations.
#
# require 'rspec/core/rake_task'
#
# RSpec::Core::RakeTask.new(:spec) do |spec|
#  spec.pattern      = './spec/*_spec.rb'
# end
#
# task :default => :spec
        EOF
        end
      else
        false
      end
    end


    def test_suite_yaml
      if !metadata.test_files.empty?
        write_if_missing("debian/ruby-test-files.yaml") do |f|
          YAML::dump(metadata.test_files, f)
        end
      else
        false
      end
    end

    def test_suite_rb
      if File::directory?("test")
        write_if_missing("debian/ruby-tests.rb") do |f|
          f.puts <<-EOF
# FIXME
# there's a test/ directory in the upstream source, but
# no test suite was defined in the Gem specification. It would be
# a good idea to define it here so the package gets tested at build time.
# Examples:
# $: << './test/'
# Dir['./test/**/*.rb'].each { |f| require f }
#
# require './test/ts_foo.rb'
#
# require 'rbconfig'
# ruby = ENV['RUBY_TEST_BIN']
# exec("\#{ruby} -I. test/runtests.rb")
        EOF
        end
      else
        false
      end
    end

    def other_files
      # docs
      docs = ""
      if File::directory?('doc')
        docs += <<-EOF
# FIXME: doc/ dir found in source. Consider installing the docs.
# Examples:
# doc/manual.html
# doc/site/*
            EOF
      end
      readmes = Dir::glob('README*')
      docs += <<-EOF
# FIXME: READMEs found
      EOF
      readmes.each do |r|
        docs << "# #{r}\n"
      end
      if docs != ""
        write_if_missing("debian/#{source_package_name}.docs") do |f|
          f.puts docs
        end
      end

      # examples
      examples = ""
      ['examples', 'sample'].each do |d|
        if File::directory?(d)
          examples += <<-EOF
# FIXME: #{d}/ dir found in source. Consider installing the examples.
# Examples:
# #{d}/*
          EOF
        end
      end
      if examples != ""
        write_if_missing("debian/#{source_package_name}.examples") do |f|
          f.puts examples
        end
      end

      # data & conf
      installs = ""
      if File::directory?('data')
        installs += <<-EOF
# FIXME: data/ dir found in source. Consider installing it somewhere.
# Examples:
# data/* /usr/share/#{source_package_name}/
        EOF
      end
      if File::directory?('conf')
        installs += <<-EOF
# FIXME: conf/ dir found in source. Consider installing it somewhere.
# Examples:
# conf/* /etc/
        EOF
      end
      if installs != ""
        write_if_missing("debian/#{source_package_name}.install") do |f|
          f.puts installs
        end
      end

      # manpages
      if File::directory?('man')
        manpages = Dir.glob("man/**/*.[1-8]")
        manpages_header = "# FIXME: man/ dir found in source. Consider installing manpages"

        write_if_missing("debian/#{source_package_name}.manpages") do |f|
          f.puts manpages_header
          manpages.each do |m|
            f.puts "# " + m
          end
        end
      end
    end
  end
end
