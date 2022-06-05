Gem::Specification.new do |s|
  s.platform = Gem::Platform::RUBY
  s.summary = "Simple gem used to test gem2tgz."
  s.name = 'simplegem14'
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
end
