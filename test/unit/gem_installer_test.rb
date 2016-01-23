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
    spec
    test
  ].each do |f|
    should "not install #{f}" do
      assert_no_file_exists installed_path(f)
    end
  end

  private

  def installed_path(file)
    INSTALLDIR + '/usr/share/rubygems-integration/all/gems/install_as_gem-0.0.1/' + file
  end


end
