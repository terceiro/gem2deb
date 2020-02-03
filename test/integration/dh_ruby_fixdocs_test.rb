require_relative '../test_helper'

class DhRubyFixDocsTest < Gem2DebTestCase

  should 'remove created.rid from doc folder' do
    docfiles = prepare('foo') do
      docfiles = Dir.glob("debian/foo/**/*")
      assert docfiles.any? { |filename| filename =~ /created.rid/ }, "#{docfiles.inspect} expected to include created.rid after prepare"

      run_command('dh_ruby_fixdocs')

      Dir.glob("debian/foo/**/*")
    end

    assert docfiles.none? { |filename| filename =~ /created.rid/ }, "#{docfiles.inspect} expected to not include created.rid"
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

      FileUtils.mkdir_p 'debian/foo/usr/share/doc/foo/rdoc'
      File.open('debian/foo/usr/share/doc/foo/rdoc/created.rid', 'w') do |f|
        f.puts("Stub rdoc timestamp file")
      end

      yield
    end
  end

end

