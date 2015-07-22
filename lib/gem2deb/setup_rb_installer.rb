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

require 'gem2deb/banner'
require 'gem2deb/dh_ruby'

module Gem2Deb

  class SetupRbInstaller < Installer

    def install_files_and_build_extensions
      ruby_versions.each do |rubyver|

        Gem2Deb::Banner.print "Install files for #{rubyver} with setup.rb"

        ruby = SUPPORTED_RUBY_VERSIONS[rubyver]
        siteruby = destdir(:libdir, rubyver)
        bindir = destdir(:bindir, rubyver)
        archdir = destdir(:archdir, rubyver)
        prefix = destdir(:prefix, rubyver)

        with_system_setuprb do
          # First configure
          run(ruby, 'setup.rb', 'config', "--prefix=#{prefix}", "--bindir=#{bindir}", "--siteruby=#{siteruby}", "--siterubyver=#{siteruby}", "--siterubyverarch=#{archdir}")

          # Then setup
          run(ruby, 'setup.rb', 'setup')

          # Then install
          run(ruby, 'setup.rb', 'install')

          # Then clean
          run(ruby, 'setup.rb', 'distclean')
        end

      end
    end

    def run_make_clean_on_extensionss
      ruby = SUPPORTED_RUBY_VERSIONS.keys.sort.first
      with_system_setuprb do
        run(ruby, 'setup.rb', 'distclean')
      end
    end

    def with_system_setuprb(*argv)
      if File.exists?('setup.rb')
        run('mv', 'setup.rb', 'setup.rb.gem2deb-orig')
      end
      run('cp', '/usr/lib/ruby/vendor_ruby/setup.rb', 'setup.rb')
      begin
        yield
      ensure
        run('rm', '-f', 'setup.rb')
        if File.exists?('setup.rb.gem2deb-orig')
          run('mv', 'setup.rb.gem2deb-orig', 'setup.rb')
        end
      end
    end

  end

end
