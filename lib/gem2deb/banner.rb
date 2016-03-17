module Gem2Deb
  module Banner
    def self.print(msg)
      $stdout.instance_eval do
        puts
        puts '┌' + '─' * 78 + '┐'
        puts '│ %-77s│' % msg
        puts '└' + '─' * 78 + '┘'
        puts
        flush
      end
    end
  end
end
