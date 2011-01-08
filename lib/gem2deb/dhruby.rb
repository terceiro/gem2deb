module Gem2Deb

  class DhRuby

    def initialize
      if File::exists?('debian/dh_ruby.overrides')
         # FIXME
      end
    end
    
    def clean
      # FIXME run make clean in ext/
    end

    def configure
    end

    def build
      if File::directory?('ext')
        puts "This library has an 'ext' dir. We don't know how to deal with it yet."
        # FIXME need to run extconf and make
        exit(1)
      end
    end

    def test
      # FIXME
    end

    def install
      # install files in bin, lib, ext, data, conf, man
      # FIXME after install, update shebang of binaries to default ruby version
    end
  end
end
