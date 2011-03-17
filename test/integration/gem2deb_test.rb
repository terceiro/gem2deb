require 'test_helper'

class Gem2DebTest < Gem2DebTestCase

  one_time_setup do
    # setup Perl lib for debhelper7
    perl5lib = File.join(tmpdir, 'perl5')
    debhelper_buildsystems = File.join(perl5lib, 'Debian/Debhelper/Buildsystem')
    FileUtils.mkdir_p debhelper_buildsystems
    FileUtils.cp 'debhelper7/ruby.pm', debhelper_buildsystems

    ENV['PERL5LIB'] = perl5lib
    ENV['PATH'] = [File.join(GEM2DEB_ROOT_SOURCE_DIR, 'bin'), ENV['PATH']].join(':')
    ENV['RUBYLIB'] = File.join(GEM2DEB_ROOT_SOURCE_DIR, 'lib')
  end

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
      silence_all_output do
        system(cmd)
      end
      if $? && ($? >> 8) > 0
        raise "Command [#{cmd}] failed!"
      end
    end
  end

end
