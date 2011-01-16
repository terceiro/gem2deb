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

module Gem2Deb
  class TestRunner
    def initialize
      @test_files = YAML.load_file('debian/ruby-test-files.yaml')

      $: << File::expand_path('lib')
      if File::directory?('ext')
        $: << File::expand_path('ext')
        # also add subdirs of ext/
        (Dir::entries('ext') - ['.', '..']).each do |e|
          if File::directory?(File.join('ext', e))
            $: << File::expand_path(File.join('ext',e))
          end
        end
      end
      $: << File::expand_path('test') if File::directory?('test')
      $: << File::expand_path('spec') if File::directory?('spec')
      $: << File::expand_path('.')

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

