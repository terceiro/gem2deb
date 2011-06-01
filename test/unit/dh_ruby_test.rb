require 'test_helper'
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
    arch = RbConfig::CONFIG['arch']
    [
      '1.8',
      '1.9.1',
    ].each do |version_number|
      target_so = "/usr/lib/ruby/vendor_ruby/#{version_number}/#{arch}/simpleextension.so"
      should "install native extension for Ruby #{version_number}" do
        assert_installed SIMPLE_EXTENSION_DIRNAME, "ruby-simpleextension", target_so
      end
      should "link #{target_so} against libruby#{version_number}" do
        installed_so = installed_file_path(SIMPLE_EXTENSION_DIRNAME, "ruby-simpleextension", target_so)
        assert_match /libruby-?#{version_number}/, `ldd #{installed_so}`
      end
    end
  end

  context 'installing native extension with extconf.rb in the sources root' do
    arch = RbConfig::CONFIG['arch']
    [
      '1.8',
      '1.9.1',
    ].each do |version_number|
      target_so = "/usr/lib/ruby/vendor_ruby/#{version_number}/#{arch}/simpleextension_in_root.so"
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
      assert_equal ['all'], @dh_ruby.send(:ruby_versions)
    end
    should 'known when all versions are supported' do
      @dh_ruby.stubs(:ruby_versions).returns(['all'])
      assert_equal true, @dh_ruby.send(:all_ruby_versions_supported?)
    end
    should 'known when not all versions are supported' do
      @dh_ruby.stubs(:ruby_versions).returns(['ruby1.8'])
      assert_equal false, @dh_ruby.send(:all_ruby_versions_supported?)
    end
    should 'rewrite shebang to use /usr/bin/ruby if all versions are supported' do
      @dh_ruby.stubs(:all_ruby_versions_supported?).returns(true)
      @dh_ruby.expects(:rewrite_shebangs).with(anything, '/usr/bin/ruby')
      @dh_ruby.send(:update_shebangs, 'foo')
    end
    should 'rewrite shebang to usr /usr/bin/ruby1.8 if only 1.8 is supported' do
      @dh_ruby.stubs(:ruby_versions).returns(['ruby1.8'])
      @dh_ruby.expects(:rewrite_shebangs).with(anything, '/usr/bin/ruby1.8')
      @dh_ruby.send(:update_shebangs, 'foo')
    end
  end

  context 'checking for require "rubygems"' do
    setup do
      @dh_ruby = Gem2Deb::DhRuby.new
      @dh_ruby.verbose = false
    end
    should 'detect require "rubygems"' do
      @dh_ruby.stubs(:ruby_source_files_in_package).returns(['test/sample/check_rubygems/bad.rb'])
      @dh_ruby.expects(:handle_test_failure).once
      @dh_ruby.send(:check_rubygems)
    end
    should 'not complain about commented require "rubygems"' do
      @dh_ruby.stubs(:ruby_source_files_in_package).returns(['test/sample/check_rubygems/good.rb'])
      @dh_ruby.expects(:handle_test_failure).never
      @dh_ruby.send(:check_rubygems)
    end
  end

  protected

  def assert_installed(gem_dirname, package, path)
    assert_file_exists installed_file_path(gem_dirname, package, path)
  end

  def read_installed_file(gem_dirname, package, path)
    File.read(installed_file_path(gem_dirname, package, path))
  end

  def installed_file_path(gem_dirname, package, path)
    File.join(self.class.tmpdir, 'ruby-' + gem_dirname, 'debian', package, path)
  end

  def self.build(gem, source_package)
    package_path = File.join(tmpdir, 'ruby-' + source_package)
    tarball =  File.join(tmpdir, source_package + '.tar.gz')
    Gem2Deb::Gem2Tgz.convert!(gem, tarball)
    Gem2Deb::DhMakeRuby.new(tarball).build

    dh_ruby = Gem2Deb::DhRuby.new
    dh_ruby.verbose = false

    silence_stream(STDOUT) do
      Dir.chdir(package_path) do
        # This sequence tries to imitate what dh will actually do
        dh_ruby.clean
        dh_ruby.configure
        dh_ruby.build
        dh_ruby.install File.join(package_path, 'debian', 'tmp')
      end
    end
  end

end
