# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)

Gem::Specification.new do |s|
  s.name        = "unsorted_names"
  s.version     = "1.0"
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Antonio Terceiro"]
  s.email       = ["terceiro@softwarelivre.org"]
  s.homepage    = ""
  s.summary     = %q{Simple gem faking code from git}
  s.description = %q{This gem is used to test the case where dh-make-ruby is called on a directory}

  s.files = %w[
    lib/file2.rb
    lib/file1.rb
    Rakefile
    unsorted_names.gemspec
  ]
  s.test_files = %w[
    lib/file2.rb
    lib/file1.rb
  ]
  s.require_paths = ["lib"]
end
