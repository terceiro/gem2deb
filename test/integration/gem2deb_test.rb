require 'test_helper'

class Gem2DebTest < Gem2DebTestCase

  Dir.glob('test/sample/*/pkg/*.gem').each do |gem|
    should "build #{gem} correcly" do
      self.class.build(gem)
      package_name = 'ruby-' + File.basename(File.dirname(File.dirname(gem))).gsub('_', '-')
      binary_packages = File.join(self.class.tmpdir, "#{package_name}*.deb")
      packages = Dir.glob(binary_packages)
      assert !packages.empty?, "building #{gem} produced no binary packages! (expected to find #{binary_packages})"
    end
  end

  protected

  def self.build(gem)
    FileUtils.cp gem, tmpdir
    gem = File.basename(gem)
    Dir.chdir(tmpdir) do
      cmd = "gem2deb -d #{gem}"
      run_command(cmd)
    end
  end

end
