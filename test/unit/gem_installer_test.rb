require_relative '../test_helper'
require 'gem2deb/gem_installer'

class GemInstallerTest < Gem2DebTestCase

  PKGDIR = 'test/sample/install_as_gem'
  INSTALLDIR = File.join(tmpdir, 'debian/ruby-install-as-gem')

  one_time_setup do
    gem_installer = Gem2Deb::GemInstaller.new('ruby-install-as-gem', PKGDIR)
    gem_installer.destdir_base = INSTALLDIR
    silently { gem_installer.install_files_and_build_extensions }
  end

  should 'install files to rubygems-integration directory' do
    assert_file_exists installed_path('lib/install_as_gem.rb')
  end

  should 'install binaries to /usr/bin' do
    assert_file_exists INSTALLDIR  + '/usr/bin/install_as_gem'
  end

  # unwanted files (first block) and directories (second block)
  %w[
    CHANGELOG
    Gemfile
    install_as_gem.gemspec
    LICENSE.TXT
    MIT-LICENSE
    Rakefile

    debian
    ext
    spec
    test
  ].each do |f|
    should "not install #{f}" do
      assert_no_file_exists installed_path(f)
    end
  end

  should 'install native extension' do
    so = Dir.glob(INSTALLDIR + '/usr/lib/**/install_as_gem/install_as_gem_native.so')
    assert_equal 1, so.size, "#{so.inspect} expected to have size 1"
  end

  private

  def installed_path(file)
    File.join(gem_install_dir, file)
  end

  def gem_install_dir
    Dir.glob(INSTALLDIR + '/usr/lib/*/rubygems-integration/*/gems/install_as_gem-0.0.1').first
  end


end