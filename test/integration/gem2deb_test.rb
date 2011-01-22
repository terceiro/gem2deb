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

    FileUtils.cp SIMPLE_GEM, tmpdir
    gem = File.basename(SIMPLE_GEM)
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

  should 'build package successfully' do
    assert_file_exists File.join(self.class.tmpdir, 'ruby-simplegem_0.0.1-1_all.deb')
  end

end
