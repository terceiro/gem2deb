require_relative '../test_helper'
require 'gem2deb/gem2tgz'
require 'gem2deb/dh_make_ruby'
require 'gem2deb/dh_ruby'
require 'rbconfig'

class DhRubyTest < Gem2DebTestCase

  one_time_setup do
    build(SIMPLE_GEM, SIMPLE_GEM_DIRNAME)
    build(SIMPLE_PROGRAM, SIMPLE_PROGRAM_DIRNAME)
    build(SIMPLE_EXTENSION, SIMPLE_EXTENSION_DIRNAME)
    build(SIMPLE_MIXED, SIMPLE_MIXED_DIRNAME)
    build(SIMPLE_ROOT_EXTENSION, SIMPLE_ROOT_EXTENSION_DIRNAME)
  end

  context 'installing simplegem' do
    should 'install pure-Ruby code' do
      assert_installed SIMPLE_GEM_DIRNAME, 'ruby-simplegem', '/usr/lib/ruby/vendor_ruby/simplegem.rb'
    end
  end

  context 'installing a Ruby program' do
    should 'install programs at /usr/bin' do
      assert_installed SIMPLE_PROGRAM_DIRNAME, 'ruby-simpleprogram', '/usr/bin/simpleprogram'
    end
    should 'rewrite shebang of installed programs' do
      assert_match %r(#!/usr/bin/ruby), read_installed_file(SIMPLE_PROGRAM_DIRNAME, 'ruby-simpleprogram', '/usr/bin/simpleprogram').lines.first
    end
  end

  context 'installing native extension' do
    SUPPORTED_VERSION_NUMBERS.each do |version_number|
      vendorarchdir = VENDOR_ARCH_DIRS['ruby' + version_number]
      target_so = "#{vendorarchdir}/simpleextension.so"
      should "install native extension for Ruby #{version_number}" do
        assert_installed SIMPLE_EXTENSION_DIRNAME, "ruby-simpleextension", target_so
      end
      should "link #{target_so} against libruby#{version_number}" do
        installed_so = installed_file_path(SIMPLE_EXTENSION_DIRNAME, "ruby-simpleextension", target_so)
        assert_match %r/libruby-?#{version_number}/, `ldd #{installed_so}`
      end
    end
  end

  context 'installing native extension with extconf.rb in the sources root' do
    SUPPORTED_VERSION_NUMBERS.each do |version_number|
      vendorarchdir = VENDOR_ARCH_DIRS['ruby' + version_number]
      target_so = "#{vendorarchdir}/simpleextension_in_root.so"
      should "install native extension for Ruby #{version_number}" do
        assert_installed SIMPLE_ROOT_EXTENSION_DIRNAME, "ruby-simpleextension-in-root", target_so
      end
    end
  end

  context 'skipping checks' do
    setup do
      @dh_ruby = Gem2Deb::DhRuby.new
      @dh_ruby.verbose = false
    end
    should 'not skip tests if DEB_BUILD_OPTIONS is not defined' do
      ENV.expects(:[]).with('DEB_BUILD_OPTIONS').returns(nil)
      assert_equal false, @dh_ruby.send(:skip_checks?)
    end
    should 'not skip tests if DEB_BUILD_OPTIONS does not include nocheck' do
      ENV.expects(:[]).with('DEB_BUILD_OPTIONS').returns('nostrip').at_least_once
      assert_equal false, @dh_ruby.send(:skip_checks?)
    end
    should 'skip tests if DEB_BUILD_OPTIONS contains exactly nocheck' do
      ENV.expects(:[]).with('DEB_BUILD_OPTIONS').returns('nocheck').at_least_once
      assert_equal true, @dh_ruby.send(:skip_checks?)
    end
    should 'skip tests if DEB_BUILD_OPTIONS contains nocheck among other options' do
      ENV.expects(:[]).with('DEB_BUILD_OPTIONS').returns('nostrip nocheck noopt').at_least_once
      assert_equal true, @dh_ruby.send(:skip_checks?)
    end
  end

  context 'running tests' do
    setup do
      @dh_ruby = Gem2Deb::DhRuby.new
      @dh_ruby.verbose = false
    end

    should 'handle test failure gracefully' do
      @dh_ruby.stubs(:skip_checks?).returns(false)
      @dh_ruby.expects(:run).raises(Gem2Deb::CommandFailed)

      @dh_ruby.expects(:handle_test_failure)

      @dh_ruby.send(:run_tests_for_version, SUPPORTED_RUBY_VERSIONS.keys.first)
    end
  end

  context 'versions supported' do
    setup do
      @dh_ruby = Gem2Deb::DhRuby.new
      @dh_ruby.verbose = false
    end
    should 'bail out if XS-Ruby-Versions is not found' do
      File.expects(:readlines).with('debian/control').returns([])
      @dh_ruby.expects(:exit).with(1)
      @dh_ruby.send(:ruby_versions)
    end
    should 'read supported versions from debian/control' do
      File.expects(:readlines).with('debian/control').returns(["XS-Ruby-Versions: all\n"])
      assert_equal SUPPORTED_RUBY_VERSIONS.keys, @dh_ruby.send(:ruby_versions)
    end
  end

  context 'installing gemspec' do
      should 'install gemspec for simplegem for all interpreters' do
        assert_installed SIMPLE_GEM_DIRNAME, 'ruby-simplegem', "/usr/share/rubygems-integration/all/specifications/simplegem-0.0.1.gemspec"
      end
    SUPPORTED_API_NUMBERS.each do |version|
      should 'install gemspec for simpleextension under Ruby ' + version do
        assert_installed SIMPLE_EXTENSION_DIRNAME, 'ruby-simpleextension', "/usr/share/rubygems-integration/#{version}/specifications/simpleextension-1.2.3.gemspec"
      end
    end
  end

  context 'DESTDIR' do
    setup do
      @dh_ruby = Gem2Deb::DhRuby.new
    end
    should 'be debian/${binary_package} by default' do
      assert_match %r/debian\/ruby-foo$/, @dh_ruby.send(:destdir_for, 'ruby-foo', 'debian/tmp')
    end
    should 'install to debian/tmp when DH_RUBY_USE_DH_AUTO_INSTALL_DESTDIR is set' do
      saved_env = ENV['DH_RUBY_USE_DH_AUTO_INSTALL_DESTDIR']
      ENV['DH_RUBY_USE_DH_AUTO_INSTALL_DESTDIR'] = 'yes'

      assert_equal 'debian/tmp', @dh_ruby.send(:destdir_for, 'ruby-foo', 'debian/tmp')

      ENV['DH_RUBY_USE_DH_AUTO_INSTALL_DESTDIR'] = saved_env
    end
  end

  protected

  def read_installed_file(gem_dirname, package, path)
    File.read(installed_file_path(gem_dirname, package, path))
  end

  def self.build(gem, source_package)
    package_path = File.join(tmpdir, 'ruby-' + source_package)
    tarball =  File.join(tmpdir, source_package + '.tar.gz')
    Gem2Deb::Gem2Tgz.convert!(gem, tarball)
    Gem2Deb::DhMakeRuby.new(tarball).build

    silently { build_package(package_path) }
  end

  def self.build_package(directory)
    Dir.chdir(directory) do

      dh_ruby = Gem2Deb::DhRuby.new
      dh_ruby.verbose = false

      silence_stream(STDOUT) do
        # This sequence tries to imitate what dh will actually do
        dh_ruby.clean
        dh_ruby.configure
        dh_ruby.build
        ENV['RUBYLIB'] = File.join(GEM2DEB_ROOT_SOURCE_DIR, 'lib')
        dh_ruby.install([File.join(directory, 'debian', 'tmp')])
      end
    end
  end

end
