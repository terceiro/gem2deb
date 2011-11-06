require 'test_helper'

class Gem2DebTest < Gem2DebTestCase

  def self.build(gem)
    FileUtils.cp gem, tmpdir
    gem = File.basename(gem)
    Dir.chdir(tmpdir) do
      cmd = "gem2deb -d #{gem}"
      run_command(cmd)
    end
  end

  Dir.glob('test/sample/*/pkg/*.gem').each do |gem|
    puts "Building #{gem} ..."
    self.build(gem)
    should "build #{gem} correcly" do
      package_name = 'ruby-' + File.basename(File.dirname(File.dirname(gem))).gsub('_', '-').downcase
      binary_packages = File.join(self.class.tmpdir, "#{package_name}_*.deb")
      packages = Dir.glob(binary_packages)
      assert !packages.empty?, "building #{gem} produced no binary packages! (expected to find #{binary_packages})"
    end
  end

  should 'generate a non-lintian-clean copyright file' do
    changes_file = File.join(self.class.tmpdir, "ruby-simplegem_*.changes")
    assert_match /E: ruby-simplegem: helper-templates-in-copyright/, `lintian #{changes_file}`
  end

  should 'not compress *.rb files installed as examples' do
    examples_package = File.join(GEM2DEB_ROOT_SOURCE_DIR, 'test/sample/examples')
    tmpdir = Dir.mktmpdir
    FileUtils.cp_r(examples_package, tmpdir)
    Dir.chdir(File.join(tmpdir, 'examples')) do
      run_command('dpkg-buildpackage -us -uc')
      assert_no_file_exists 'debian/ruby-examples/usr/share/doc/ruby-examples/examples/test.rb.gz'
      assert_file_exists 'debian/ruby-examples/usr/share/doc/ruby-examples/examples/test.rb'
    end
    FileUtils.rm_rf(tmpdir)
  end

end
