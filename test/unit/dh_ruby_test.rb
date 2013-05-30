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
    build(SIMPLE_EXTENSION_WITH_NAME_CLASH, SIMPLE_EXTENSION_WITH_NAME_CLASH_DIRNAME)
    build_from_tree('test/sample/multibinary')
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
      assert_match %r(#!/usr/bin/env ruby), read_installed_file(SIMPLE_PROGRAM_DIRNAME, 'ruby-simpleprogram', '/usr/bin/simpleprogram').lines.first
    end
  end

  context 'installing native extension' do
    [
      '1.8',
      '1.9.1',
    ].each do |version_number|
      vendorarchdir = VENDOR_ARCH_DIRS['ruby' + version_number]
      target_so = "#{vendorarchdir}/simpleextension.so"
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
    [
      '1.8',
      '1.9.1',
    ].each do |version_number|
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

  context 'libraries with name clash (between foo.rb and foo.so)' do
    should "install symlinks for foo.rb in Ruby 1.8 vendorlibdir" do
      symlink = installed_file_path(SIMPLE_EXTENSION_WITH_NAME_CLASH_DIRNAME, 'ruby-simpleextension-with-name-clash', "/usr/lib/ruby/vendor_ruby/1.8/simpleextension_with_name_clash.rb")
      assert_file_exists symlink
    end
    should 'not install symlink for foo.rb in Ruby 1.9 vendorlibdir' do
      symlink = installed_file_path(SIMPLE_EXTENSION_WITH_NAME_CLASH_DIRNAME, 'ruby-simpleextension-with-name-clash', "/usr/lib/ruby/vendor_ruby/1.9.1/simpleextension_with_name_clash.rb")
      assert !File.exist?(symlink), 'should not install symlink for Ruby 1.9 (it\'s not needed'
    end
  end

  context 'name clash with multiple binary packages' do
    setup do
      FileUtils.cp_r('test/sample/name_clash_multiple/', tmpdir)
      @target_dir = File.join(tmpdir, 'name_clash_multiple')
      self.class.build_package(@target_dir)
    end
    should 'work' do
      symlink = File.join(@target_dir, 'debian/ruby-name-clash/usr/lib/ruby/vendor_ruby/1.8/name_clash.rb')
      assert File.exist?(symlink), 'symlink not installed at %s!' % symlink
    end
  end

  context 'installing gemspec' do
    should 'install gemspec for simplegem' do
      assert_installed SIMPLE_GEM_DIRNAME, 'ruby-simplegem', '/usr/share/rubygems-integration/1.9.1/specifications/simplegem-0.0.1.gemspec'
    end
  end

  context "multi-binary source packages" do
    should 'install program in ruby-foo' do
      assert_installed 'multibinary', 'ruby-foo', '/usr/bin/foo', false
    end
    should 'install library in ruby-foo' do
      assert_installed 'multibinary', 'ruby-foo', '/usr/lib/ruby/vendor_ruby/foo.rb', false
    end
    should 'install program in ruby-bar' do
      assert_installed 'multibinary', 'ruby-bar', '/usr/bin/bar', false
    end
    should 'install library in ruby-bar' do
      assert_installed 'multibinary', 'ruby-bar', '/usr/lib/ruby/vendor_ruby/bar.rb', false
    end
  end

  context "selecting package layout" do

    setup do
      @dh_ruby = Gem2Deb::DhRuby.new
      @dh_ruby.verbose = false
    end

    should 'default to single-binary' do
      debian_control << 'Package: ruby-foo'
      debian_control << 'Package: ruby-bar'
      ruby_foo = { :binary_package => 'ruby-foo', :root => '.' }
      assert_equal [ruby_foo], @dh_ruby.send(:packages)
    end

    should 'ignore packages without X-DhRuby-Root when one of them has it' do
      debian_control << 'Package: ruby-foo'
      debian_control << 'Package: ruby-bar'
      debian_control << 'X-DhRuby-Root: bar'

      ruby_bar = { :binary_package => 'ruby-bar', :root => 'bar' }
      assert_equal [ruby_bar], @dh_ruby.send(:packages)
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

    build_package(package_path)
  end

  def self.build_from_tree(directory)
    FileUtils.cp_r(directory, tmpdir)
    target = File.join(tmpdir, File.basename(directory))
    build_package(target)
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
        dh_ruby.install([File.join(directory, 'debian', 'tmp')])
      end
    end
  end

end
