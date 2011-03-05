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
    {
      '1.8'   => 'ruby1.8',
      '1.9.1' => 'ruby1.9.1',
    }.each do |version_number, version_name|
      target_so = "/usr/lib/ruby/vendor_ruby/#{version_number}/#{arch}/simpleextension.so"
      should "install native extension for #{version_name}" do
        assert_installed SIMPLE_EXTENSION_DIRNAME, "#{version_name}-simpleextension", target_so
      end
      should "link #{target_so} against lib#{version_name}" do
        installed_so = installed_file_path(SIMPLE_EXTENSION_DIRNAME, "#{version_name}-simpleextension", target_so)
        assert_match /libruby-?#{version_number}/, `ldd #{installed_so}`
      end
    end
    should "update the shebang to use the default ruby version" do
      assert_match %r(#!/usr/bin/ruby1.8), read_installed_file(SIMPLE_EXTENSION_DIRNAME, 'ruby-simpleextension', '/usr/bin/simpleextension').lines.first.strip
    end
  end

  context 'determining ruby version for package' do
    {
      'foo' => 'ruby',
      'ruby-foo' => 'ruby',
      'ruby1.8-foo' => 'ruby1.8',
      'ruby1.9.1-foo' => 'ruby1.9.1',
    }.each do |package,version|
      should "detect #{version} for package '#{package}'" do
        assert_equal version, Gem2Deb::DhRuby.new.send(:ruby_version_for, package)
      end
    end
  end

  context 'mixed packages (both pure-Ruby and native library code)' do
    should 'install Ruby libraries into single package' do
      dh_ruby = Gem2Deb::DhRuby.new
      dh_ruby.stubs(:packages).returns(['ruby-foo'])
      assert_equal ['ruby-foo'], dh_ruby.send(:packages_to_install_libraries_in)
    end

    should 'install Ruby libraries in native packages' do
      dh_ruby = Gem2Deb::DhRuby.new
      dh_ruby.stubs(:packages).returns(['ruby-foo', 'ruby1.8-foo', 'ruby1.9.1-foo'])
      assert_equal ['ruby1.8-foo', 'ruby1.9.1-foo'], dh_ruby.send(:packages_to_install_libraries_in)
    end

    should 'install Ruby code in ruby-foo-common package if it is present' do
      dh_ruby = Gem2Deb::DhRuby.new
      dh_ruby.stubs(:packages).returns(['ruby-foo', 'ruby1.8-foo', 'ruby1.9.1-foo', 'ruby-foo-common'])
      assert_equal ['ruby-foo-common'], dh_ruby.send(:packages_to_install_libraries_in)
    end

    should 'install programs in single package' do
      dh_ruby = Gem2Deb::DhRuby.new
      dh_ruby.stubs(:packages).returns(['ruby-foo'])
      assert_equal ['ruby-foo'], dh_ruby.send(:packages_to_install_programs_in)
    end

    should 'install programs in common package if present' do
      dh_ruby = Gem2Deb::DhRuby.new
      dh_ruby.stubs(:packages).returns(['ruby-foo', 'ruby1.8-foo', 'ruby1.9.1-foo', 'ruby-foo-common'])
      assert_equal ['ruby-foo-common'], dh_ruby.send(:packages_to_install_programs_in)
    end

    should 'duplicate pure-Ruby code in native packages' do
      assert_installed SIMPLE_MIXED_DIRNAME, 'ruby1.8-simplemixed', '/usr/lib/ruby/vendor_ruby/1.8/simplemixed.rb' 
      assert_installed SIMPLE_MIXED_DIRNAME, 'ruby1.9.1-simplemixed', '/usr/lib/ruby/vendor_ruby/1.9.1/simplemixed.rb'
    end

  end

  context 'calculating libdir for each package' do
    {
      'ruby-foo' => '/usr/lib/ruby/vendor_ruby',
      'ruby1.8-foo' => '/usr/lib/ruby/vendor_ruby/1.8',
      'ruby1.9.1-foo' => '/usr/lib/ruby/vendor_ruby/1.9.1',
    }.each do |package,path|
      should "install Ruby code for #{package} at #{path}" do
        assert_equal path, Gem2Deb::DhRuby.new.send(:libdir_for, package)
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
    instance = Gem2Deb::DhRuby.new
    instance.verbose = false

    package_path = File.join(tmpdir, 'ruby-' + source_package)
    tarball =  File.join(tmpdir, source_package + '.tar.gz')
    Gem2Deb::Gem2Tgz.convert!(gem, tarball)
    Gem2Deb::DhMakeRuby.new(tarball).build

    silence_stream(STDOUT) do
      Dir.chdir(package_path) do
        # This sequence tries to imitate what dh will actually do
        instance.clean
        instance.configure
        instance.build
        binary_packages = `dh_listpackages`.split
        instance.install File.join(package_path, 'debian', 'tmp')
      end
    end
  end

end
