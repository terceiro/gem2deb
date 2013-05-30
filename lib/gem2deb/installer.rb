require 'gem2deb/metadata'

module Gem2Deb

  class Installer

    class RequireRubygemsFound < Exception; end

    include Gem2Deb

    EXTENSION_BUILDER = File.expand_path(File.join(File.dirname(__FILE__),'extension_builder.rb'))

    attr_reader :binary_package
    attr_reader :root
    attr_reader :metadata

    attr_reader :ruby_versions
    attr_accessor :verbose
    attr_accessor :dh_auto_install_destdir

    def initialize(binary_package, root, ruby_versions = SUPPORTED_RUBY_VERSIONS.keys)
      @binary_package = binary_package
      @root = File.expand_path(root)
      @ruby_versions = ruby_versions
      @metadata = Gem2Deb::Metadata.new(@root)
    end

    def install_files_and_build_extensions
      install_files(bindir, destdir(:bindir), 755) if File::directory?(bindir)

      install_files(libdir, destdir(:libdir), 644) if File::directory?(libdir)

      if metadata.has_native_extensions?
        ruby_versions.each do |rubyver|
          puts "Building extension for #{rubyver} ..." if verbose
          run("#{SUPPORTED_RUBY_VERSIONS[rubyver]} -I#{LIBDIR} #{EXTENSION_BUILDER} #{binary_package}")

          # Remove duplicate files installed by rubygems in the arch dir
          # This is a hack to workaround a problem in rubygems
          vendor_dir = destdir(:libdir)
          vendor_arch_dir = destdir(:archdir, rubyver)
          if File::exists?(vendor_dir) and File::exists?(vendor_arch_dir)
            remove_duplicate_files(vendor_dir, vendor_arch_dir)
          end
        end
      end

      install_symlinks
      install_changelog
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
      File.open("debian/#{binary_package}.substvars", "a") do |fd|
        fd.puts "ruby:Versions=#{ruby_versions.join(' ')}"
      end
    end

    def install_gemspec
      if metadata.gemspec
        ruby_versions.each do |version|
          target = File.join(destdir(:root), "/usr/share/rubygems-integration/#{RUBY_CONFIG_VERSION[version]}/specifications/#{metadata.name}-#{metadata.version}.gemspec")
          FileUtils.mkdir_p(File.dirname(target))
          File.open(target, 'w') do |file|
            file.write(metadata.gemspec.to_ruby)
          end
        end
      end
    end

    def check_rubygems
      found = false
      if File::exists?('debian/require-rubygems.overrides')
        overrides = YAML::load_file('debian/require-rubygems.overrides')
      else
        overrides = []
      end
      installed_ruby_files.each do |f|
        lines = readlines(f)
        rglines = lines.select { |l| l =~ /require.*rubygems/  && l !~ /^\s*#/ }
          rglines.each do |l|
          if not overrides.include?(f)
            puts "#{f}: #{l}" if verbose
            found = true
          end
          end
      end
      if found
        puts "Found some 'require rubygems' without overrides (see above)." if verbose
        raise RequireRubygemsFound
      end
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

    protected

    def all_ruby_versions_supported?
      ruby_versions == SUPPORTED_RUBY_VERSIONS.keys
    end

    def bindir
      @bindir ||= File.join(self.root, 'bin')
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

    def destdir_base
      if ENV['DH_RUBY_USE_DH_AUTO_INSTALL_DESTDIR']
        puts 'W: Using DH_RUBY_USE_DH_AUTO_INSTALL_DESTDIR is deprecated and will be removed in the future. Please see dh_ruby(1) for the supported way for producing multiple binary packages.' if verbose
        self.dh_auto_install_destdir
      else
        File.join('debian', binary_package)
      end
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


    def install_symlinks
      ruby_versions.select { |v| v == 'ruby1.8' }.each do |rubyver|
        archdir = destdir(:archdir, rubyver)
        vendordir = destdir(:libdir, rubyver)
        vendorlibdir = File.dirname(archdir)
        Dir.glob(File.join(archdir, '*.so')).each do |so|
          rb = File.basename(so).gsub(/\.so$/, '.rb')
          if File.exists?(File.join(vendordir, rb))
            Dir.chdir(vendorlibdir) do
              file_handler.ln_s "../#{rb}", rb
            end
          end
        end
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
          if old =~ /ruby/ or old !~ /^#!/
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

    def installed_ruby_files
      Dir["debian/#{binary_package}/usr/lib/ruby/vendor_ruby/**/*.rb"]
    end

    def install_changelog
      changelog = Dir.glob(File.join(root, 'CHANGELOG*')).first
      if changelog
        run("dh_installchangelogs -p#{binary_package} #{changelog} upstream")
      end
    end

  end

end
