# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "simplegit/version"

Gem::Specification.new do |s|
  s.name        = "simplegit"
  s.version     = Simplegit::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Antonio Terceiro"]
  s.email       = ["terceiro@softwarelivre.org"]
  s.homepage    = ""
  s.summary     = %q{Simple gem faking code from git}
  s.description = %q{This gem is used to test the case where dh-make-ruby is called on a directory}

  s.files = %w[
    lib
    lib/simplegit.rb
    lib/simplegit
    lib/simplegit/version.rb
    Rakefile
    simplegit.gemspec
  ]
  s.require_paths = ["lib"]
end
