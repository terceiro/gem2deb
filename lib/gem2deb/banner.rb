module Gem2Deb
  module Banner
    def self.print(msg)
      puts
      puts '┌' + '─' * 78 + '┐'
      puts '│ %-77s│' % msg
      puts '└' + '─' * 78 + '┘'
      puts
    end
  end
end
