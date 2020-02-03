require_relative '../test_helper'

class DhRubyFixDependsTest < Gem2DebTestCase

  should 'insert ruby dependency' do
    deps = prepare('foo') do
      run_command('dh_ruby_fixdepends')

      File.readlines("debian/foo.substvars").find { |l| l =~ /^shlibs:Depends=/ }.strip.sub('shlibs:Depends=', '').split(/,\s*/)
    end

    Gem2Deb::SUPPORTED_RUBY_SHARED_LIBRARIES.each do |shlib|
      assert deps.any? { |dep| dep.split(/\s*\|\s*/).include?(shlib) }, "#{deps.inspect} expected to include '#{shlib.inspect} (>= something)'"
    end
    assert deps.any? { |dep| dep =~ /ruby \(>= [^)]*\)/ }, "#{deps.inspect} expected to include 'ruby (>= something)'"
  end

  def prepare(package)
    pkgdir = File.join(tmpdir, package)
    FileUtils.mkdir(pkgdir)
    Dir.chdir(pkgdir) do
      FileUtils.mkdir 'debian'

      File.open('debian/control', 'w') do |control|
        control.puts("Source: #{package}")
        control.puts('Maintainer: The Maintainer <maintainer@example.com>')
        control.puts('XS-Ruby-Versions: all')
        control.puts
        control.puts("Package: #{package}")
        control.puts('Architecture: any')
        control.puts('Depends: ${shlibs:Depends}, ruby')
        control.puts('Description: example package')
        control.puts(' Just for testing')
      end

      File.open("debian/#{package}.substvars", 'w') do |substvars|
        substvars.puts('shlibs:Depends=' + Gem2Deb::SUPPORTED_RUBY_SHARED_LIBRARIES.join(', '))
      end

      yield
    end
  end

end

