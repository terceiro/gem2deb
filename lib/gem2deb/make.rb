module Gem2Deb

  class Make

    include Gem2Deb

    def initialize
      init_builders
    end

    def clean
      run_builders(:clean, true)
    end

    def build
      run_builders
    end

    def install(destdir)
      run_builders([:install, "DESTDIR=#{destdir}"])
    end

    protected # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    def init_builders
      @builders = []
      if File.exist?('debian/dh_ruby.mk')
        @builders << ['make', '-f', 'debian/dh_ruby.mk']
      end
      if File.exist?('debian/dh_ruby.rake')
        @builders << ['rake', '-f', 'debian/dh_ruby.rake']
      end
    end

    def run_builders(target=nil, ignore_failure=false)
      @builders.each do |builder|
        begin
          cmdline = (builder + Array(target).map(&:to_s)).compact
          run(*cmdline)
        rescue Gem2Deb::CommandFailed
          raise unless ignore_failure
        end
      end
    end

  end


end
