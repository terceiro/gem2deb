# Copyright © 2010, Antonio Terceiro <terceiro@softwarelivre.org>
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

require 'fileutils'
require 'tmpdir'

require 'gem2deb'
include Gem2Deb

module Gem2Deb

  class Gem2Tgz

    GEMEXT = /(\.gem)$/
    TGZEXT = /(\.tgz|\.tar\.gz)$/

    def self.convert!(gem, tarball = nil)
      self.new(gem, tarball).convert!
    end

    attr_reader :gem, :gem_full_path
    attr_reader :tarball, :tarball_full_path
    attr_reader :target_dir

    def initialize(gem, tarball = nil)
      if gem =~ GEMEXT || gem =~ TGZEXT
        @ext                = $1
        @gem                = gem
        @gem_full_path      = File.expand_path(gem)
        @tarball            = tarball
        if @tarball.nil?
          # the _ -> - substitution is required because '_' is invalid
          # in Debian packages names
          # same for downcase
          @tarball = @gem.gsub(@ext, '.tar.gz').gsub(/_/,'-').downcase
        end
        @tarball_full_path  = File.expand_path(@tarball)
        @target_dirname     = File::basename(@tarball).gsub('.tar.gz', '')
      else
        puts "#{gem} does not look like a valid .gem file."
        exit(1)
      end
    end

    def convert!
      create_target_dir
      extract_gem_contents if @ext =~ GEMEXT
      extract_tgz_contents if @ext =~ TGZEXT
      create_resulting_tarball
      cleanup
      @tarball
    end

    protected

    def create_target_dir
      @tmp_dir = Dir::mktmpdir('gem2tgz')
      @target_dir = @tmp_dir + '/' + @target_dirname
      Dir::mkdir(@target_dir)
    end

    def extract_gem_contents
      Dir.chdir(@target_dir) do
        run "tar xfm #{gem_full_path}"
        run 'tar xzfm data.tar.gz'
        FileUtils.rm_f('data.tar.gz')
        run "zcat metadata.gz > metadata.yml"
        FileUtils.rm_f('metadata.gz')
      end
    end

    def extract_tgz_contents
      Dir.chdir(@target_dir) do
        run "tar xfm #{gem_full_path} --strip 1"
      end
    end

    def create_resulting_tarball
      Dir.chdir(@tmp_dir) do
        run "tar czf #{@tarball_full_path} #{@target_dirname}"
      end
    end

    def cleanup
      FileUtils.rm_rf(@tmp_dir)
    end

  end
end
