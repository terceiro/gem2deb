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

    def initialize
      packages = []
      multibinary = false
      lines =
        begin
          File.readlines('debian/control')
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
    end

  end

end
