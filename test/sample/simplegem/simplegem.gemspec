Gem::Specification.new do |s|
  s.platform = Gem::Platform::RUBY
  s.summary = "Simple gem used to test gem2tgz."
  s.name = 'simplegem'
  s.version = '0.0.1'
  s.requirements << 'none'
  s.require_path = 'lib'
  s.author = 'Debian Ruby Team'
  s.email = 'pkg-ruby-extras-maintainers@lists.alioth.debian.org'
  s.homepage = 'https://wiki.debian.org/Teams/Ruby'
  s.license = 'GPL-3+'
  #s.autorequire = 'rake'
  s.files = Dir.glob('lib/**')
  s.description = <<EOF
simplegem is a simple gem that is used to test gem2tgz.
EOF

  s.add_runtime_dependency 'dep'
  s.add_runtime_dependency 'depwithversion', '1.0'
  s.add_runtime_dependency 'depwithspermy', '~> 1.0'
  s.add_runtime_dependency 'depwithgt', '> 1.0'
  s.add_runtime_dependency 'depwith2versions', '>= 1.0', '< 2.0'
  s.add_runtime_dependency 'railties', '>= 6.0', '< 7.0'
  s.add_runtime_dependency 'depwithlte', '>= 1.0', '<= 2.1'
  s.add_runtime_dependency 'different', '!= 1.0'
end
