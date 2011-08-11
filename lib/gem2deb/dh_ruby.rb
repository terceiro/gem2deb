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
require 'gem2deb/metadata'
require 'find'
require 'fileutils'

module Gem2Deb

  class DhRuby

    SUPPORTED_RUBY_VERSIONS = {
      #name             Ruby binary
      #---------------  -------------------
      'ruby1.8'   => '/usr/bin/ruby1.8',
      'ruby1.9.1' => '/usr/bin/ruby1.9.1',
    }

    RUBY_BINARY = '/usr/bin/ruby'

    DEFAULT_RUBY_VERSION = 'ruby1.8'

    RUBY_CODE_DIR = '/usr/lib/ruby/vendor_ruby'

    include Gem2Deb

    attr_accessor :verbose

    attr_reader :metadata

    def initialize
      @verbose = true
      @bindir = '/usr/bin'
      @skip_checks = nil
      @metadata = Gem2Deb::Metadata.new('.')
    end
    
    def clean
      puts "  Entering dh_ruby --clean" if @verbose
      run_make_clean_on_extensions
      puts "  Leaving dh_ruby --clean" if @verbose
    end

    def configure
      # puts "  Entering dh_ruby --configure" if @verbose
      # puts "  Leaving dh_ruby --configure" if @verbose
    end

    def build
      # puts "  Entering dh_ruby --build" if @verbose
      # puts "  Leaving dh_ruby --build" if @verbose
    end

    def test
      # puts "  Entering dh_ruby --test" if @verbose
      # puts "  Leaving dh_ruby --test" if @verbose
    end

    EXTENSION_BUILDER = File.expand_path(File.join(File.dirname(__FILE__),'extension_builder.rb'))
    TEST_RUNNER = File.expand_path(File.join(File.dirname(__FILE__),'test_runner.rb'))
    LIBDIR = File.expand_path(File.join(File.dirname(__FILE__), '..'))

    attr_accessor :dh_auto_install_destdir

    def install(argv)
      puts "  Entering dh_ruby --install" if @verbose

      self.dh_auto_install_destdir = argv.first

      supported_versions =
        if all_ruby_versions_supported?
          SUPPORTED_RUBY_VERSIONS.keys.clone
        else
          ruby_versions.clone
        end

      package = packages.first

      install_files_and_build_extensions(package, supported_versions)

      run_tests(supported_versions)

      install_substvars(package, supported_versions)

      update_shebangs(package)

      check_rubygems

      puts "  Leaving dh_ruby --install" if @verbose
    end

    protected

    # This function returns the installation path for the given
    # package and the given "component", which is one of:
    # * :bindir
    # * :libdir
    # * :archdir
    # * :prefix
    #
    # _rubyver_ is the ruby version, needed only for :archdir for now.
    def destdir(package, which, rubyver = nil)
      case which
      when :bindir
        return File.join(destdir_for(package), @bindir)
      when :libdir
        return File.join(destdir_for(package), RUBY_CODE_DIR)
      when :archdir
        return File.join(destdir_for(package), `#{SUPPORTED_RUBY_VERSIONS[rubyver]} -rrbconfig -e "puts RbConfig::CONFIG['vendorarchdir']"`.chomp)
      when :prefix
        return File.join(destdir_for(package), "usr/")
      end
    end


    def install_files_and_build_extensions(package, supported_versions)
      install_files('bin', destdir(package, :bindir), 755) if File::directory?('bin')

      install_files('lib', destdir(package, :libdir), 644) if File::directory?('lib')

      if metadata.has_native_extensions?
        supported_versions.each do |rubyver|
          puts "Building extension for #{rubyver} ..." if @verbose
          run("#{SUPPORTED_RUBY_VERSIONS[rubyver]} -I#{LIBDIR} #{EXTENSION_BUILDER} #{package}")

          # Remove duplicate files installed by rubygems in the arch dir
          # This is a hack to workaround a problem in rubygems
          vendor_dir = destdir(package, :libdir)
          vendor_arch_dir = destdir(package, :archdir, rubyver)
          if File::exists?(vendor_dir) and File::exists?(vendor_arch_dir)
            remove_duplicate_files(vendor_dir, vendor_arch_dir)
          end
        end
      end

      install_symlinks(package, supported_versions)
    end

    def install_symlinks(package, supported_versions)
      supported_versions.select { |v| v == 'ruby1.8' }.each do |rubyver|
        archdir = destdir(package, :archdir, rubyver)
        vendordir = destdir(package, :libdir, rubyver)
        vendorlibdir = File.dirname(archdir)
        Dir.glob(File.join(archdir, '*.so')).each do |so|
          rb = File.basename(so).gsub(/\.so$/, '.rb')
          if File.exists?(File.join(vendordir, rb))
            Dir.chdir(vendorlibdir) do
              FileUtils.ln_s "../#{rb}", rb
            end
          end
        end
      end
    end

    def remove_duplicate_files(src, dst)
      candidates = (Dir::entries(src) & Dir::entries(dst)) - ['.', '..']
      candidates.each do |cand|
        if File::file?(File.join(src, cand)) and File::file?(File.join(dst, cand)) and IO::read(File.join(src, cand)) == IO::read(File.join(dst, cand))
          FileUtils::Verbose.rm(File.join(dst, cand))
        elsif File::directory?(File.join(src, cand)) and File::directory?(File.join(dst, cand))
          files_src = files_dst = nil
          Dir::chdir(File.join(src, cand)) do
            files_src = Dir::glob('**/*', File::FNM_DOTMATCH).sort
          end
          Dir::chdir(File.join(dst, cand)) do
            files_dst = Dir::glob('**/*', File::FNM_DOTMATCH).sort
          end
          if files_src == files_dst
            if files_src.all? { |f| File.ftype(File.join(src, f)) == File.ftype(File.join(dst, f)) and (not File.file?(File.join(src, f)) or IO::read(File.join(src, cand)) == IO::read(File.join(dst, cand))) }
              FileUtils::Verbose.rm_rf(File.join(dst, cand))
            end
          end
        end
      end
    end

    def check_rubygems
      if skip_checks?
        return
      end
      found = false
      if File::exists?('debian/require-rubygems.overrides')
        overrides = YAML::load_file('debian/require-rubygems.overrides')
      else
        overrides = []
      end
      packages.each do |pkg|
        pkg.chomp!
        ruby_source_files_in_package(pkg).each do |f|
          lines = IO::readlines(f)
          rglines = lines.select { |l| l =~ /require.*rubygems/  && l !~ /^\s*#/ }
          rglines.each do |l|
            if not overrides.include?(f)
              puts "#{f}: #{l}" if @verbose
              found = true
            end
          end
        end
      end
      if found
        puts "Found some 'require rubygems' without overrides (see above)." if @verbose
        handle_test_failure('require-rubygems')
      end
    end

    def ruby_source_files_in_package(pkg)
      Dir["debian/#{pkg}/usr/lib/ruby/vendor_ruby/**/*.rb"]
    end

    def handle_test_failure(test)
      if ENV['DH_RUBY_IGNORE_TESTS']
        if ENV['DH_RUBY_IGNORE_TESTS'].split.include?('all')
          puts "WARNING: Test \"#{test}\" failed, but ignoring all test results."
          return
        elsif ENV['DH_RUBY_IGNORE_TESTS'].split.include?(test)
          puts "WARNING: Test \"#{test}\" failed, but ignoring this test result."
          return
        end
      end
      if STDIN.isatty and STDOUT.isatty and STDERR.isatty
        # running interactively
        continue = nil
        begin
          puts
          print "Test \"#{test}\" failed. Continue building the package? (Y/N) "
          STDOUT.flush
          c = STDIN.getc
          continue = true if c.chr.downcase == 'y'
          continue = false if c.chr.downcase == 'n'
        end while continue.nil?
        if not continue
          exit(1)
        end
      else
          puts "ERROR: Test \"#{test}\" failed. Exiting."
          exit(1)
      end
    end

    def run_tests(supported_versions)
      supported_versions.each do |rubyver|
        if !run_tests_for_version(rubyver)
          supported_versions.delete(rubyver)
        end
      end
    end

    def run_tests_for_version(rubyver)
      if skip_checks?
        return
      end

      cmd = "#{SUPPORTED_RUBY_VERSIONS[rubyver]} -I#{LIBDIR} #{TEST_RUNNER}"
      puts(cmd) if $VERBOSE
      system(cmd)

      if $?.exitstatus != 0
        handle_test_failure(rubyver)
        return false
      else
        return true
      end
    end

    def install_substvars(package, supported_versions)
      File.open("debian/#{package}.substvars", "a") do |fd|
        fd.puts "ruby:Versions=#{supported_versions.join(' ')}"
      end
    end

    def skip_checks?
      if @skip_checks.nil?
        if ENV['DEB_BUILD_OPTIONS'] && ENV['DEB_BUILD_OPTIONS'].split(' ').include?('nocheck')
          puts "DEB_BUILD_OPTIONS includes nocheck, skipping all checks (test suite, rubygems usage etc)." if @verbose
          @skip_checks = true
        else
          @skip_checks = false
        end
      end
      @skip_checks
    end

    JUNK_FILES = %w( RCSLOG tags TAGS .make.state .nse_depinfo )
    HOOK_FILES = %w( pre-%s post-%s pre-%s.rb post-%s.rb ).map {|fmt|
      %w( config setup install clean ).map {|t| sprintf(fmt, t) }
      }.flatten
    JUNK_PATTERNS = [ /^#/, /^\.#/, /^cvslog/, /^,/, /^\.del-*/, /\.olb$/,
        /~$/, /\.(old|bak|BAK|orig|rej)$/, /^_\$/, /\$$/, /\.org$/, /\.in$/, /^\./ ]

    DO_NOT_INSTALL = (JUNK_FILES + HOOK_FILES).map { |file| /^#{file}$/ } + JUNK_PATTERNS

    def install_files(src, dest, mode)
      run "install -d #{dest}"
      files_to_install = Dir.chdir(src) do
        Dir.glob('**/*').reject do |file|
          filename = File.basename(file)
          File.directory?(file) || DO_NOT_INSTALL.any? { |pattern| filename =~ pattern }
        end
      end
      files_to_install.each do |file|
        from = File.join(src, file)
        to = File.join(dest, file)
        run "install -D -m#{mode} #{from} #{to}"
      end
    end

    def destdir_for(package)
      destdir =
        if ENV['DH_RUBY_USE_DH_AUTO_INSTALL_DESTDIR']
          self.dh_auto_install_destdir
        else
          File.join('debian', package)
        end
      File.expand_path(destdir)
    end

    def update_shebangs(package)
      ruby_binary =
        if all_ruby_versions_supported?
          RUBY_BINARY
        else
          SUPPORTED_RUBY_VERSIONS[ruby_versions.first]
        end
      rewrite_shebangs(package, ruby_binary)
    end

    def rewrite_shebangs(package, ruby_binary)
      Dir.glob(File.join(destdir_for(package), @bindir, '**/*')).each do |path|
        next if File.directory?(path)
        puts "Rewriting shebang line of #{path}" if @verbose
        atomic_rewrite(path) do |input, output|
          old = input.gets # discard
          output.puts "#!#{ruby_binary}"
          unless old =~ /#!/
            output.puts old
          end
          output.print input.read
        end
      end
    end

    def atomic_rewrite(path, &block)
      tmpfile = path + '.tmp'
      begin
        File.open(tmpfile, 'wb') do |output|
          File.open(path, 'rb') do |input|
            yield(input, output)
          end
        end
        File.rename tmpfile, path
      ensure
        File.unlink tmpfile if File.exist?(tmpfile)
      end
    end

    def packages
      @packages ||= `dh_listpackages`.split
    end

    def ruby_versions
      @ruby_versions ||=
        begin
          # find ruby versions to build the package for.
          lines = File.readlines('debian/control').grep(/^XS-Ruby-Versions: /)
          if lines.empty?
            puts "No XS-Ruby-Versions: field found in source!" if @verbose
            exit(1)
          else
            lines.first.split[1..-1]
          end
        end
    end

    def all_ruby_versions_supported?
      ruby_versions.include?('all')
    end

    def run_make_clean_on_extensions
      if metadata.has_native_extensions?
        metadata.native_extensions.each do |extension|
          extension_dir = File.dirname(extension)
          if File.exists?(File.join(extension_dir, 'Makefile'))
            puts "Running 'make distclean || make clean' in #{extension_dir}..."
            Dir.chdir(extension_dir) do
              run 'make distclean || make clean'
            end
          end
        end
      end
    end
  end
end
