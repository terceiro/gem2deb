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

if defined?(Encoding) && Encoding.default_external.name == 'US-ASCII'
  Encoding.default_external = 'UTF-8'
end

require 'ruby_debian_dev'

module Gem2Deb

  class CommandFailed < Exception
  end

  include RubyDebianDev

  SUPPORTED_RUBY_VERSIONS.select! do |version, binary|
    # To help backporters without having to also backport the interpreters.
    File.exist?(binary)
  end

  RUBY_SHEBANG_CALL = '/usr/bin/ruby'

  BIN_DIR = '/usr/bin'

  RUBY_CODE_DIR = '/usr/lib/ruby/vendor_ruby'

  LIBDIR = File.expand_path(File.dirname(__FILE__))

  def run(*argv)
    puts(_format_cmdline(argv)) if $VERBOSE
    system(*argv)
    if $?.exitstatus != 0
      raise Gem2Deb::CommandFailed, _format_cmdline(argv)
    end
  end

  private

  def _format_cmdline(argv)
    argv.map { |a| a =~ /\s/ && a.inspect || a }.join(' ')
  end
end

require 'gem2deb/version'
