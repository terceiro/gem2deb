# Copyright © 2011, Antonio Terceiro <terceiro@softwarelivre.org>
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

module Gem2Deb
  class RubyVersion

    include Gem2Deb

    SUPPORTED_RUBY_VERSIONS = {
      #name             Ruby binary           arch-indep libraries dir
      #---------------  --------------------- ------------------------------------
      'ruby1.8'   => %w(/usr/bin/ruby1.8      /usr/lib/ruby/vendor_ruby/1.8     ),
      'ruby1.9.1' => %w(/usr/bin/ruby1.9.1    /usr/lib/ruby/vendor_ruby/1.9.1   ),
    }

    class << self
      def by_package(package)
        @by_package ||= {}
        if @by_package.has_key?(package)
          @by_package[package]
        else
          version = SUPPORTED_RUBY_VERSIONS.keys.find do |version|
            package =~ /^#{version.first}-/
          end
          @by_package[package] = version ? new(version) : nil
        end
      end
      private :new
    end

    attr_reader :version
    attr_reader :ruby_binary
    attr_reader :libdir

    def inspect
      "<#{version}>"
    end

    def build_extensions(destdir)
      extension_builder = File.join(File.dirname(__FILE__),'extension_builder.rb')
      run("#{ruby_binary} #{extension_builder} #{destdir}")
    end

    private

    def initialize(version)
      @version = version
      @ruby_binary = SUPPORTED_RUBY_VERSIONS[version][0]
      @libdir = SUPPORTED_RUBY_VERSIONS[version][1]
    end

  end
end
