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
    end

    def build
      create_orig_tarball
      extract
      create_debian_boilerplates
      create_control
      other_files
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
      if @tarball =~ /^(.*)_(.*).orig.tar.gz$/
        @gem_name = $1
        @gem_version = $2
        @orig_tarball = @tarball
      elsif @tarball =~ /^(.*)-(.*).tar.gz$/
        @gem_name = $1
        @gem_version = $2
        @orig_tarball = "#{@gem_name}_#{@gem_version}.orig.tar.gz"
        run("ln -sf #{@tarball} #{@orig_tarball}")
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
      Dir::mkdir("#{@gem_name}-#{@gem_version}/debian")
      Dir::chdir("#{@gem_name}-#{@gem_version}/debian") do
        # changelog
        Dir::chdir('..') do
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
        Dir::mkdir('source')
        File::open('source/format','w') { |f| f.puts "3.0 (quilt)" }
      end
    end

    def create_control
      spec = YAML::load(IO::read("#{@gem_name}-#{@gem_version}/metadata.yml"))
      f = File::new("#{@gem_name}-#{@gem_version}/debian/control", 'w')
      f.puts <<-EOF
Source: #{@gem_name}
Section: ruby
Priority: optional
Maintainer: Debian Ruby Extras Maintainers <pkg-ruby-extras-maintainers@lists.alioth.debian.org>
Uploaders: #{ENV['DEBFULLNAME']} <#{ENV['DEBEMAIL']}>
DM-Upload-Allowed: yes
Build-Depends: debhelper (>= 7.0.50~), gem2deb (>= #{Gem2Deb::VERSION})
Standards-Version: 3.8.4
#Vcs-Git: git://git.debian.org/collab-maint/libnet-jabber-loudmouth-perl.git
#Vcs-Browser: http://git.debian.org/?p=collab-maint/libnet-jabber-loudmouth-perl.git;a=summary
EOF
      if spec.homepage 
        f.puts "Homepage: #{spec.homepage}"
      else
        f.puts "Homepage: FIXME"
      end
      f.puts
      f.puts "Package: ruby-#{@gem_name}"
      if spec.require_paths && spec.require_paths.include?('ext')
        f.puts "Architecture: any"
      else
        f.puts "Architecture: all"
      end
      f.puts "Depends: ${shlibs:Depends}, ${misc:Depends}"
      if spec.dependencies.length > 0
        f.print "# "
        spec.dependencies.each do |dep|
          f.print "#{dep.name} (#{dep.requirement})"
        end
        f.puts
      end
      f.print "Description: "
      if spec.summary
        f.puts spec.summary
      else
        f.puts "FIXME"
      end
      if spec.description
        spec.description.each_line do |l|
          l = l.strip
          if l == ""
            f.puts ' .'
          else
            f.puts " #{l}"
          end
        end
      else
        f.puts " <insert long description, indented with spaces>"
      end
      f.close
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
        if File::directory?('examples')
          File::open("debian/ruby-#{@gem_name}.examples", 'w') do |f|
            f.puts <<-EOF
# FIXME: examples/ dir found in source. Consider installing the examples.
# Examples:
# examples/*
            EOF
          end
        end
      end
    end
  end
end
