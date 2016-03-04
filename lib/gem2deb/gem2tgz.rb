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
require 'digest'
require 'yaml'
require 'zlib'

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
          path = File.dirname(@gem)
          filename = File.basename(@gem)

          # the _ -> - substitution is required because '_' is invalid
          # in Debian packages names
          # same for downcase
          filename = filename.gsub(@ext, '.tar.gz').gsub(/_/,'-').downcase

          @tarball = File.join(path, filename)
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
        run('tar', 'xfm', gem_full_path)
        verify_and_strip_checksums if File.exist?('checksums.yaml.gz')
        run 'tar xzfm data.tar.gz'
        FileUtils.rm_f('data.tar.gz')
        if Dir['*.gemspec'].empty?
          run "zcat metadata.gz > metadata.yml"
          gemspec = YAML.load_file('metadata.yml')
          gemspec.executables.sort!
          gemspec.extensions.sort!
          gemspec.extra_rdoc_files.sort!
          gemspec.files.sort!
          gemspec.require_paths.sort!
          gemspec.test_files.sort!
          gemspec.dependencies.sort!
          File.open("#{gemspec.name}.gemspec", 'w') do |f|
            f.puts "#########################################################"
            f.puts "# This file has been automatically generated by gem2tgz #"
            f.puts "#########################################################"
            f.puts(gemspec.to_ruby)
          end
          FileUtils.rm_f('metadata.yml')
        end
        FileUtils.rm_f('metadata.gz')
      end
    end

    def extract_tgz_contents
      Dir.chdir(@target_dir) do
        run('tar', 'xfm', gem_full_path, '--strip', '1')
      end
    end

    def create_resulting_tarball
      Dir.chdir(@tmp_dir) do
        run('tar', 'czf', @tarball_full_path, @target_dirname)
      end
    end

    def cleanup
      FileUtils.rm_rf(@tmp_dir)
    end

    def verify_and_strip_checksums
      checksums = read_checksums
      [Digest::SHA1, Digest::SHA512].each do |digest|
        hash_name = digest.name.sub(/^Digest::/,'')
        ["data.tar.gz", "metadata.gz"].each do |f|
          unless correct_checksum?(digest, f, checksums[hash_name][f])
            puts "E: (#{gem}) the #{hash_name} checksum for #{f} is inconsistent with the one recorded in checksums.yaml.gz"
            exit(1)
          end
        end
      end
      FileUtils.rm_f('checksums.yaml.gz')
    end

    def read_checksums
      Zlib::GzipReader.open('checksums.yaml.gz') do |checksums_file|
        YAML.load(checksums_file.read)
      end
    end

    def correct_checksum?(digest, f, checksum)
      digest.file(f).hexdigest == checksum
    end

  end
end
