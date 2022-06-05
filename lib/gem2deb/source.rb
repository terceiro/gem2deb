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

module Gem2Deb

  class Source

    attr :packages
    attr :debhelper_compat
    attr :build_depends

    def initialize
      packages = []
      multibinary = false
      lines =
        begin
          # unwrap rfc822 continuation lines
          File.readlines('debian/control').inject([]) do |memo, line|
            if line =~ /^\s/
              memo.last << line.strip
            else
              memo << line.strip
            end
            memo
          end
        rescue Errno::ENOENT
          []
        end

      lines.each do |line|
        if line =~ /^Package:\s*(\S*)\s*$/
          package = $1
          packages.push({ :binary_package => package })
        elsif line =~ /^X-DhRuby-Root:\s*(\S*)\s*$/
          root = $1
          if packages.last
            packages.last[:root] = root
          end
          multibinary = true
        elsif line =~ /^Build-Depends:\s*(.*)\s*$/
          @build_depends = $1.split(/\s*,\s*/)
        end
      end

      if multibinary
        @packages = packages.select { |p| p[:root] }
      else
        package = packages.first
        if package
          package[:root] = '.'
          @packages = [package]
        else
          @packages = []
        end
      end

      @debhelper_compat = get_debhelper_compat
    end

    def separate_build_test_install
      debhelper_compat && debhelper_compat >= 14
    end

    def build_dir
      if separate_build_test_install
        ".gem2deb"
      else
        "debian"
      end
    end

    private

    def get_debhelper_compat
      if ENV["DH_COMPAT"]
        ENV["DH_COMPAT"].to_i
      elsif File.exist?("debian/compat")
        File.read('debian/compat').strip.to_i
      else
        @build_depends&.find do |d|
          d =~ /debhelper-compat\s*\(\s*=\s*(\d+)\s*\)/
        end
        $1.to_i
      end
    end

  end

end
