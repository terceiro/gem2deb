require 'gem2deb/banner'
require 'gem2deb/metadata'

module Gem2Deb

  class Installer

    include Gem2Deb

    EXTENSION_BUILDER = File.expand_path(File.join(File.dirname(__FILE__),'extension_builder.rb'))

    attr_reader :binary_package
    attr_reader :root
    attr_reader :metadata

    attr_reader :ruby_versions
    attr_accessor :verbose
    attr_accessor :destdir_base

    def initialize(binary_package, root, ruby_versions = SUPPORTED_RUBY_VERSIONS.keys)
      @binary_package = binary_package
      @root = File.expand_path(root)
      @ruby_versions = ruby_versions
      @metadata = Gem2Deb::Metadata.new(@root)
    end

    def install
      install_files_and_build_extensions
      update_shebangs
      install_substvars
      install_gemspec
      install_changelog
    end

    def clean
      run_make_clean_on_extensions
    end

    # The public API ends here
    # ----------------8<----------------8<----------------8<-----------------

    protected

    def install_files_and_build_extensions

      Gem2Deb::Banner.print "Install files"
      install_files(bindir, destdir(:bindir), 755, metadata.executables) if File::directory?(bindir)
      install_files(libdir, destdir(:libdir), 644) if File::directory?(libdir)

      if metadata.has_native_extensions?
        ruby_versions.each do |rubyver|
          Gem2Deb::Banner.print "Build native extensions for #{rubyver}" if verbose

          run_ruby(SUPPORTED_RUBY_VERSIONS[rubyver], EXTENSION_BUILDER, root, destdir_base)

          # Remove duplicate files installed by rubygems in the arch dir
          # This is a hack to workaround a problem in rubygems
          vendor_dir = destdir(:libdir)
          vendor_arch_dir = destdir(:archdir, rubyver)
          if File::exists?(vendor_dir) and File::exists?(vendor_arch_dir)
            remove_duplicate_files(vendor_dir, vendor_arch_dir)
          end
        end
      end
    end

    def update_shebangs
      ruby_binary =
        if all_ruby_versions_supported?
          RUBY_SHEBANG_CALL
        else
          SUPPORTED_RUBY_VERSIONS[ruby_versions.first]
        end
      rewrite_shebangs(ruby_binary)
    end

    def install_substvars
      versions =
        if all_ruby_versions_supported? && !metadata.has_native_extensions?
          ['all']
        else
          ruby_versions
        end
      dependencies = metadata.get_debian_dependencies(false)
      File.open("debian/#{binary_package}.substvars", "a") do |fd|
        fd.puts "ruby:Versions=#{versions.join(' ')}"
        fd.puts "ruby:Depends=#{dependencies.join(', ')}"
      end
    end

    def install_gemspec
      Gem2Deb::Banner.print "Install Rubygems integration metadata"
      if metadata.gemspec
        versions =
          if metadata.has_native_extensions?
            ruby_versions.map { |v| RUBY_API_VERSION[v] }
          else
            ['all']
          end
        versions.each do |version|
          target = File.join(destdir(:root), "/usr/share/rubygems-integration/#{version}/specifications/#{metadata.name}-#{metadata.version}.gemspec")
          puts "generating gemspec at #{target}"
          FileUtils.mkdir_p(File.dirname(target))
          gemspec = metadata.gemspec.dup
          # Do not include extensions in the gemspec to avoid bundler not being able to
          # indentify if the extensions were correctly built. For more info check Bug #972702.
          gemspec.extensions = []
          File.open(target, 'w') do |file|
            file.write(gemspec.to_ruby)
          end
        end
      end
    end

    def run_make_clean_on_extensions
      if metadata.has_native_extensions?
        metadata.native_extensions.each do |extension|
          extension_dir = File.dirname(extension)
          if File.exist?(File.join(extension_dir, 'Makefile'))
            puts "Running 'make distclean || make clean' in #{extension_dir}..."
            Dir.chdir(extension_dir) do
              run 'make distclean || make clean'
            end
          end
        end
      end
    end

    def install_changelog
      changelog = Dir.glob(File.join(root, 'CHANGELOG*')).first
      if changelog
        run("dh_installchangelogs", "-p#{binary_package}", changelog, "upstream")
      end
    end

    def all_ruby_versions_supported?
      ruby_versions == supported_ruby_versions
    end

    def supported_ruby_versions
      SUPPORTED_RUBY_VERSIONS.keys
    end

    def bindir
      @bindir ||= File.join(self.root, metadata.bindir)
    end

    def libdir
      @libdir ||= File.join(self.root, 'lib')
    end

    # This function returns the installation path for the given
    # package and the given target, which is one of:
    # * :bindir
    # * :libdir
    # * :archdir
    # * :prefix
    #
    # _rubyver_ is the ruby version, needed only for :archdir for now.
    def destdir(target, rubyver = nil)
      dir = File.expand_path(destdir_base)

      case target
      when :root
        return dir
      when :bindir
        return File.join(dir, BIN_DIR)
      when :libdir
        return File.join(dir, RUBY_CODE_DIR)
      when :archdir
        return File.join(dir, `#{SUPPORTED_RUBY_VERSIONS[rubyver]} -rrbconfig -e "puts RbConfig::CONFIG['vendorarchdir']"`.chomp)
      when :prefix
        return File.join(dir, "usr/")
      end
    end

    JUNK_FILES = %w( RCSLOG tags TAGS .make.state .nse_depinfo )
    HOOK_FILES = %w( pre-%s post-%s pre-%s.rb post-%s.rb ).map {|fmt|
      %w( config setup install clean ).map {|t| sprintf(fmt, t) }
      }.flatten
    JUNK_PATTERNS = [ /^#/, /^\.#/, /^cvslog/, /^,/, /^\.del-*/, /\.olb$/,
        /~$/, /\.(old|bak|BAK|orig|rej)$/, /^_\$/, /\$$/, /\.org$/, /\.in$/, /^\./ ]

    DO_NOT_INSTALL = (JUNK_FILES + HOOK_FILES).map { |file| /^#{file}$/ } + JUNK_PATTERNS


    def install_files(src, dest, mode, files_to_install = nil)
      run("install", "-d", dest)
      files_to_install ||= Dir.chdir(src) do
        Dir.glob('**/*').reject do |file|
          filename = File.basename(file)
          File.directory?(file) || DO_NOT_INSTALL.any? { |pattern| filename =~ pattern }
        end
      end
      files_to_install.each do |file|
        from = File.join(src, file)
        to = File.join(dest, file)
        run("install", "-D", "-m#{mode}", from, to)
      end
    end

    def remove_duplicate_files(src, dst)
      candidates = Dir::entries(src) - ['.', '..']
      candidates.each do |cand|
        file1 = File.join(src, cand)
        file2 = File.join(dst, cand)
        if File.file?(file1) and File.file?(file2) and (File.read(file1) == File.read(file2))
          file_handler.rm(file2)
        elsif File.directory?(file1) and File.directory?(file2)
          remove_duplicate_files(file1, file2)
        end
      end
      if (Dir.entries(dst) - ['.', '..']).empty?
        file_handler.rmdir(dst)
      end
    end

    def file_handler
      @verbose ? FileUtils::Verbose : FileUtils
    end

    def rewrite_shebangs(ruby_binary)
      Dir.glob(File.join(destdir(:bindir), '**/*')).each do |path|
        next if File.directory?(path)
        atomic_rewrite(path) do |input, output|
          old = input.gets
          if old =~ /^#!\s*\/.*ruby/
            puts "Rewriting shebang line of #{path}" if @verbose
            output.puts "#!#{ruby_binary}"
            unless old =~ /#!/
              output.puts old
            end
          else
            puts "Not rewriting shebang line of #{path}" if @verbose
            output.puts old
          end
          output.print input.read
        end
        File.chmod(0755, path)
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

    def readlines(filename)
      if String.instance_methods.include?(:valid_encoding?)
        File.readlines(filename).select { |l| l.valid_encoding? }
      else
        File.readlines(filename)
      end
    end

  end

end
