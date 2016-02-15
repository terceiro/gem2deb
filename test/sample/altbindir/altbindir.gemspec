# coding: utf-8

Gem::Specification.new do |spec|
  spec.name          = "altbindir"
  spec.version       = '1'
  spec.authors       = ["Antonio Terceiro"]
  spec.email         = ["terceiro@debian.org"]

  spec.summary       = %q{test gem}
  spec.description   = %q{test gem}
  spec.homepage      = "https://www.debian.org/"

  spec.files         = Dir.glob('**/*')
  spec.bindir        = "exe"
  spec.executables   = %w(altbindir)
  spec.require_paths = ["lib"]
end
