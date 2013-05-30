spec = Gem::Specification.new do |s|
  s.platform = Gem::Platform::RUBY
  s.summary = "Simple bar library"
  s.name = 'bar'
  s.version = '0.0.1'
  s.requirements << 'none'
  s.require_path = 'lib'
  s.files = Dir.glob('lib/**') + Dir.glob('bin/*')
  s.description = <<EOF
bar ...
EOF
end
