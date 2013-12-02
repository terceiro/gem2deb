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

module Gem2Deb

  class CommandFailed < Exception
  end

  SUPPORTED_RUBY_VERSIONS = {

    #name             Ruby binary
    #---------------  -------------------
    'ruby1.9.1' => '/usr/bin/ruby1.9.1',
    'ruby2.0'   => '/usr/bin/ruby2.0',

  }.select do |version, binary|
    # To help backporters without having to also backport the interpreters.
    File.exists?(binary)
  end

  RUBY_CONFIG_VERSION = {
    'ruby1.9.1' => '1.9.1',
    'ruby2.0'   => '2.0',
  }

  SUPPORTED_RUBY_SHARED_LIBRARIES = [
    'libruby1.9.1',
    'libruby2.0',
  ]

  RUBY_SHEBANG_CALL = '/usr/bin/env ruby'

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
