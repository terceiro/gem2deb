require_relative '../test_helper'
require 'gem2deb/yaml'

class Gem2DebYamlTest < Gem2DebTestCase

  def sample(f)
    File.join(SAMPLE_DIR, 'yaml_gemspecs', f)
  end

  should 'load gemspec' do
    Gem2Deb::YAML.load_gemspec(sample('ruby-sigar.yml'))
  end

  should 'load gemspec with aliases' do
    Gem2Deb::YAML.load_gemspec(sample('ruby-bert.yml'))
  end

  should 'load gemspec using Gem::Version::Requirement' do
    Gem2Deb::YAML.load_gemspec(sample('ruby-metaid.yml'))
  end

  should 'load gemspec using Date' do
    Gem2Deb::YAML.load_gemspec(sample('ruby-text-format.yml'))
  end

end
