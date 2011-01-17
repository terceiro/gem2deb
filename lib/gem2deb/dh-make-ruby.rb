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
require 'rubygems'
require 'yaml'
require 'pp'

include Gem2Deb

module Gem2Deb

  class DhMakeRuby

    def initialize(tarball)
      @tarball = tarball
      @tarball_name = File.basename(@tarball)
      @tarball_dir = File.dirname(@tarball)
    end

    def build
      Dir.chdir(@tarball_dir) do
        create_orig_tarball
        extract
        read_spec
        create_debian_boilerplates
        create_control
        other_files
        test_suite
      end
    end
    
    def read_spec
      @spec = YAML::load(IO::read("#{@gem_name}-#{@gem_version}/metadata.yml"))
    end

    def build_dir
      "#{@gem_name}-#{@gem_version}"
    end

    def buildpackage(binary = true)
      Dir::chdir("#{@gem_name}-#{@gem_version}") do
        bin = binary ? '' : '-S'
        run("dpkg-buildpackage -us -uc #{bin}")
      end
    end

    def create_orig_tarball
      if @tarball_name =~ /^(.*)_(.*).orig.tar.gz$/
        @gem_name = $1
        @gem_version = $2
        @orig_tarball = @tarball_name
      elsif @tarball_name =~ /^(.*)-(.*).tar.gz$/
        @gem_name = $1
        @gem_version = $2
        @orig_tarball = "#{@gem_name}_#{@gem_version}.orig.tar.gz"
        run("ln -sf #{@tarball_name} #{@orig_tarball}")
      else
        raise "Could not determine gem name and version: #{@tarball}"
      end
    end

    def extract
      run("tar xzf #{@orig_tarball}")
      if not File::directory?("#{@gem_name}-#{@gem_version}")
        raise "Extracting did not create #{@gem_name}-#{@gem_version} directory."
      end
    end

    def create_debian_boilerplates
      if not File::directory?("#{@gem_name}-#{@gem_version}/debian")
        Dir::mkdir("#{@gem_name}-#{@gem_version}/debian")
      end
      Dir::chdir("#{@gem_name}-#{@gem_version}/debian") do
        # changelog
        Dir::chdir('..') do
          if File::exists?('debian/changelog')
            FileUtils::rm('debian/changelog')
          end
          run "dch --create --empty --fromdirname 'Initial release (Closes: #nnnn)'"
        end

        # compat
        File::open('compat','w') { |f| f.puts "7" }

        # copyright
        File::open('copyright', 'w') do |f|
          f.puts "FIXME. fill-in with DEP5 copyright file. http://dep.debian.net/deps/dep5/"
        end

        # rules
        File::open('rules', 'w') do |f|
          f.puts <<-EOF
#!/usr/bin/make -f
#export DH_VERBOSE=1
#
# Uncomment to ignore all test failures
#export DH_RUBY_IGNORE_TESTS=all
#
# Uncomment to ignore some test failures. Valid values:
#export DH_RUBY_IGNORE_TESTS=ruby1.8 ruby1.9.1 require-rubygems

%:
\tdh $@ --buildsystem=ruby
          EOF
        end
        run("chmod a+rx rules")

        # watch
        File::open('watch','w') do |f|
          f.puts <<-EOF
version=3
http://pkg-ruby-extras.alioth.debian.org/cgi-bin/gemwatch/#{@gem_name} .*/#{@gem_name}-(.*).tar.gz
          EOF
        end

        # source/format
        Dir::mkdir('source') if not File::directory?('source')
        File::open('source/format','w') { |f| f.puts "3.0 (quilt)" }
      end
    end

    def create_control
      f = File::new("#{@gem_name}-#{@gem_version}/debian/control", 'w')
      f.puts <<-EOF
Source: #{@gem_name}
Section: ruby
Priority: optional
Maintainer: Debian Ruby Extras Maintainers <pkg-ruby-extras-maintainers@lists.alioth.debian.org>
Uploaders: #{ENV['DEBFULLNAME']} <#{ENV['DEBEMAIL']}>
DM-Upload-Allowed: yes
Build-Depends: debhelper (>= 7.0.50~), gem2deb (>= #{Gem2Deb::VERSION})
Standards-Version: 3.9.1
#Vcs-Git: git://git.debian.org/collab-maint/libnet-jabber-loudmouth-perl.git
#Vcs-Browser: http://git.debian.org/?p=collab-maint/libnet-jabber-loudmouth-perl.git;a=summary
EOF
      if @spec.homepage 
        f.puts "Homepage: #{@spec.homepage}"
      else
        f.puts "Homepage: FIXME"
      end
      f.puts
      pkg = ""
      pkg << "Package: RUBYVER-#{@gem_name}\n"
      pkg << "Architecture: RUBYARCH\n"
      pkg << "Depends: ${shlibs:Depends}, ${misc:Depends}\n"
      if @spec.dependencies.length > 0
        pkg << "# "
        @spec.dependencies.each do |dep|
          pkg << "#{dep.name} (#{dep.requirement})"
        end
        pkg << "\n"
      end
       pkg << "Description: "
      if @spec.summary
        pkg << @spec.summary + "\n"
      else
        pkg << "FIXME\n"
      end
      if @spec.description
        @spec.description.each_line do |l|
          l = l.strip
          if l == ""
            pkg << ' .\n'
          else
            pkg << " #{l}\n"
          end
        end
      else
        pkg << " <insert long description, indented with spaces>"
      end

      f.puts pkg.gsub('RUBYVER', 'ruby').gsub('RUBYARCH', 'all')
      f.puts
      if File::directory?("#{@gem_name}-#{@gem_version}/ext")
        [ 'ruby1.8', 'ruby1.9.1'].each do |rver|
          f.puts pkg.gsub('RUBYVER', rver).gsub('RUBYARCH', 'any')
          f.puts
        end
      end
      f.close
    end

    def test_suite
      if not @spec.test_files.empty?
        File::open("#{@gem_name}-#{@gem_version}/debian/ruby-test-files.yaml", 'w') do |f|
          YAML::dump(@spec.test_files, f)
        end
      else
        if File::directory?("#{@gem_name}-#{@gem_version}/test") or File::directory?("#{@gem_name}-#{@gem_version}/spec")
          File::open("#{@gem_name}-#{@gem_version}/debian/ruby-tests.rb", 'w') do |f|
            f.puts <<-EOF
# FIXME
# there's a spec/ or a test/ directory in the upstream source, but
# no test suite was defined in the Gem specification. It would be
# a good idea to define it here so the package gets tested at build time.
# Example:
# $: << 'lib'
# Dir['{spec,test}/**/*.rb'].each { |f| require f }
            EOF
          end
        end
      end
    end

    def other_files
      Dir::chdir("#{@gem_name}-#{@gem_version}") do
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
          File::open("debian/ruby-#{@gem_name}.docs", 'w') do |f|
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
          File::open("debian/ruby-#{@gem_name}.examples", 'w') do |f|
            f.puts examples
          end
        end

        # data & conf
        installs = ""
        if File::directory?('data')
          installs += <<-EOF
# FIXME: data/ dir found in source. Consider installing it somewhere.
# Examples:
# data/* /usr/share/ruby-#{@gem_name}/
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
          File::open("debian/ruby-#{@gem_name}.install", 'w') do |f|
            f.puts installs
          end
        end
      end
    end
  end
end
