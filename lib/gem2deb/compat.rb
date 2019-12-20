require 'erb'

module Gem2Deb
  module Compat

    class ERB < ::ERB
      def initialize(template)
        if RUBY_VERSION >= '2.7'
          super(template, trim_mode: '<>')
        else
          super(template, nil, '<>')
        end
      end
    end

  end
end

