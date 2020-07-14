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

Encoding.default_external = 'UTF-8'

require 'ruby_debian_dev'

module Gem2Deb

  class << self
    attr_accessor :verbose
    def testing
      ENV['GEM2DEB_TESTING']
    end
    def testing=(v)
      ENV['GEM2DEB_TESTING'] = v.to_s
    end
  end

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
    puts(_format_cmdline(argv)) if Gem2Deb.verbose
    system(*argv)
    if $?.exitstatus != 0
      raise Gem2Deb::CommandFailed, _format_cmdline(argv)
    end
  end

  def run_ruby(ruby, *args)
    cmd = args.dup
    if LIBDIR != '/usr/lib/ruby/vendor_ruby'
      # only add LIBDIR to load path is not running the installed copy
      cmd.unshift("-I", LIBDIR)
    end
    cmd.unshift(ruby)
    run(*cmd)
  end

  def make_cmd
    flags = "-fdebug-prefix-map=#{root}=."
    cc = [ENV.fetch('CC', 'gcc'), flags].join(' ')
    cxx = [ENV.fetch('CXX', 'g++'), flags].join(' ')
    "make V=1 CC='#{cc}' CXX='#{cxx}'"
  end

  private

  def _format_cmdline(argv)
    argv.map { |a| a =~ /\s/ && a.inspect || a }.join(' ')
  end
end

Gem2Deb.verbose = true

require 'gem2deb/version'
