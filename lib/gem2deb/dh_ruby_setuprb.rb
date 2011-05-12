# Copyright © 2011, Vincent Fourmond <fourmond@debian.org>
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

require 'gem2deb/dh_ruby'

module Gem2Deb

  class DhRubySetupRb < DhRuby

    def install_files_and_build_extensions(package, supported_versions)
      for rubyver in supported_versions
        ruby = SUPPORTED_RUBY_VERSIONS[rubyver]
        siteruby = destdir(package, :libdir, rubyver)
        bindir = destdir(package, :bindir, rubyver)
        archdir = destdir(package, :archdir, rubyver)
        prefix = destdir(package, :prefix, rubyver)

        # First configure
        run("#{ruby} setup.rb config --prefix=#{prefix} --bindir=#{bindir} --siteruby=#{siteruby} --siterubyver=#{siteruby} --siterubyverarch=#{archdir}")

        # Then setup
        run("#{ruby} setup.rb setup")

        # Then install
        run("#{ruby} setup.rb install")

        # Then clean
        run("#{ruby} setup.rb distclean")
        
      end
    end


    def run_tests(supported_versions)
      puts "Running tests is currently not supported for ruby_setuprb"
    end


  end

end
