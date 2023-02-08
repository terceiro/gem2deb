require 'date'
require 'yaml'

module Gem2Deb
  module YAML
    def self.load_gemspec(file)
      ::YAML.safe_load(
        File.open(file),
        aliases: true,
        permitted_classes: [
          Date,
          Gem::Dependency,
          Gem::Requirement,
          Gem::Specification,
          Gem::Version,
          'Gem::Version::Requirement',
          Symbol,
          Time,
        ],
      )
    end
  end
end
