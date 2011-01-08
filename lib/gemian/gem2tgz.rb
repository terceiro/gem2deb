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

class Gem2Tgz

  VERSION = '0.1.0'

  class CommandFailed < Exception
  end

  def self.convert!(gem, tarball)
    self.new(gem, tarball).convert!
  end

  attr_reader :gem, :gem_full_path
  attr_reader :tarball, :tarball_full_path
  attr_reader :target_dir

  def initialize(gem, tarball)
    @gem                = gem
    @gem_full_path      = File.expand_path(gem)
    @tarball            = tarball
    @tarball_full_path  = File.expand_path(tarball)
    @target_dir         = tarball_full_path.gsub('.tar.gz', '')
  end

  def convert!
    create_target_dir
    extract_gem_contents
    create_resulting_tarball
    cleanup
  end

  protected

  def create_target_dir
    FileUtils.mkdir_p(target_dir)
  end

  def extract_gem_contents
    Dir.chdir(target_dir) do
      run "tar xfm #{gem_full_path}"
      run 'tar xzfm data.tar.gz'
      FileUtils.rm_f('data.tar.gz')
      run "zcat metadata.gz > metadata.yml"
      FileUtils.rm_f('metadata.gz')
    end
  end

  def create_resulting_tarball
    Dir.chdir(File.dirname(tarball_full_path)) do
      run "tar czf #{File.basename(tarball)} #{File.basename(target_dir)}"
    end
  end

  def cleanup
    FileUtils.rm_rf(target_dir)
  end

  def run(cmd)
    system(cmd)
    if $? && ($? >> 8) > 0
      raise Gem2Tgz::CommandFailed, "[#{cmd} failed!]"
    end
  end

end
