require 'yaml'

module Gem2Deb
  module YAML
    def self.load_gemspec(file)
      ::YAML.safe_load_file(
        file,
        permitted_classes: [
          Gem::Dependency,
          Gem::Requirement,
          Gem::Specification,
          Gem::Version,
          Symbol,
          Time,
        ],
      )
    end
  end
end
