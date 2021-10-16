require_relative '../test_helper'
require 'gem2deb/gem_installer'

class GemInstallerTest < Gem2DebTestCase

  PKGDIR = 'test/sample/install_as_gem'
  INSTALLDIR = File.join(tmpdir, 'debian/ruby-install-as-gem')

  one_time_setup do
    gem_installer = Gem2Deb::GemInstaller.new('ruby-install-as-gem', PKGDIR)
    gem_installer.destdir_base = INSTALLDIR

    orig_include_list = gem_installer.send(:include_list)
    gem_installer.stubs(:include_list).returns(orig_include_list + ['included.md'])
    silently { gem_installer.send(:install_files_and_build_extensions) }
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
    README.md
    bin/setup
    bin/console

    debian
    ext
    spec
    test
    tests
    examples
  ].each do |f|
    should "not install #{f}" do
      assert_no_file_exists installed_path(f)
    end
  end

  should 'install VERSION' do
    assert_file_exists installed_path("VERSION")
  end

  should 'install file in include_list' do
    assert_file_exists installed_path("included.md")
  end

  should 'not install extra_rdoc_files' do
    assert_no_file_exists installed_path('extra_rdoc.md')
  end

  should 'install native extension' do
    so = Dir.glob(INSTALLDIR + '/usr/lib/**/install_as_gem/install_as_gem_native.so')
    assert_equal Gem2Deb::SUPPORTED_RUBY_VERSIONS.keys.size, so.size, "#{so.inspect} expected to have size 1"
  end

  should 'drop executable bit from non-script Ruby files' do
    lib = installed_path('lib/install_as_gem.rb')
    assert_equal '100644', File.stat(lib).mode.to_s(8)
  end

  private

  def installed_path(file)
    File.join(gem_install_dir, file)
  end

  def gem_install_dir
    Dir.glob(INSTALLDIR + '/usr/lib/*/rubygems-integration/*/gems/install_as_gem-0.0.1').first
  end


end
