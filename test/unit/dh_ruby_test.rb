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
      assert_match %r(#!/usr/bin/ruby1.8), read_installed_file(SIMPLE_PROGRAM_DIRNAME, 'ruby-simpleprogram', '/usr/bin/simpleprogram').lines.first.strip
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
    should "update the shebang to use the default ruby version" do
      assert_match %r(#!/usr/bin/ruby1.8), read_installed_file(SIMPLE_EXTENSION_DIRNAME, 'ruby-simpleextension', '/usr/bin/simpleextension').lines.first.strip
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
