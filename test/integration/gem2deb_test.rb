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

end
