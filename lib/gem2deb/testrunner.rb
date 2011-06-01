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

require 'rbconfig'

module Gem2Deb
  class TestRunner
    def initialize
      @test_files = YAML.load_file('debian/ruby-test-files.yaml')

      # We should only use installation paths for the current Ruby
      # version.
      #
      # We assume that installation has already proceeded into
      # subdirectories of the debian/ directory.

      dirs = Dir["debian/*/usr/lib/ruby/vendor_ruby"]
      dirs += Dir["debian/*" + RbConfig::CONFIG['vendorarchdir']]

      $:.concat(dirs)

      # And we add the current directory:
      $: << "."

      @test_files.each do |f|
        require f
      end
    end
  end
end

if $PROGRAM_NAME == __FILE__
  if ARGV.length == 0
    Gem2Deb::TestRunner::new
  else
    puts "usage: #{File.basename($PROGRAM_NAME)}"
    exit(1)
  end
end

