module Gem2Deb
  class PackageNameMapping
    attr_reader :data

    def initialize(global = true)
      @data = {}
      if global
        get_data_from_archive!
      else
        get_data_from_installed_packages!
      end
    end

    def [](gem_name)
      @data[gem_name] || 'ruby-' + gem_name.downcase.gsub('_', '-')
    end

    def get_data_from_archive!
      if Gem2Deb.testing
        @data = { 'rake' => 'rake', 'rails' => 'rails' }
        return
      end
      if !system('which apt-file >/dev/null')
        puts "E: apt-file not found. Please install the package apt-file"
        exit 1
      end

      cache_dir = File.join(ENV['HOME'], '.cache', 'gem2deb')
      FileUtils.mkdir_p(cache_dir)
      cache = File.join(cache_dir, 'gem_to_packages.yaml')

      if File.exist?(cache)
        stat = File.stat(cache)
        update = (Time.now.to_i - stat.mtime.to_i) > (60*60*24) # keep cache for 24h
      else
        update = true
      end

      if update
        new_cache = cache + ".new.#{$$}"
        if system('apt-file search /usr/share/rubygems-integration/ | grep \'.gemspec$\' > ' + new_cache)
          if File.stat(new_cache).size > 0
            system('sed', '-i', '-e', 's#/.*/##; s/-[0-9.]\+.gemspec//', new_cache)
            FileUtils.mv(new_cache, cache)
          else
            puts 'E: dh-make-ruby needs an up-to-date apt-file cache in order to map gem names'
            puts 'E: to package names but apt-file has an invalid cache. Please run '
            puts 'E: `apt update` and make sure that `apt-file search` works.'
            exit 1
          end
        else
          puts 'E: dh-make-ruby needs an up-to-date apt-file cache in order to map gem names to package names'
          puts 'E: make sure that apt-file has an updated cache (run `apt update`)'
          exit $?.exitstatus
        end
      end

      data = ::YAML.load_file(cache)
      unless data.respond_to?(:invert)
        File.unlink(cache)
        puts 'E: Failed to load "gem name to package name" cache from'
        puts '   ' +  cache
        puts 'I: The existing cache was removed and will be rebuilt next time.'
        puts 'I: please try again.'
        exit 1
      end
      @data = data.invert
    end

    def get_data_from_installed_packages!
      io = IO.popen("dpkg -S /usr/share/rubygems-integration/*/specifications/*", "r")
      @data = io.readlines.inject({}) do |memo, line|
        pkg, gemspec = line.strip.split(/:\s+/)
        pkg.gsub!(/:.*/, '')
        _gem = File.basename(gemspec).sub(/-[0-9.]+\.gemspec$/, '')
        memo[_gem] = pkg
        memo
      end
    end
  end
end
