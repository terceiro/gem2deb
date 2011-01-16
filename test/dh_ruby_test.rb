require 'test/helper'
require 'gem2deb/dhruby'
require 'rbconfig'
require 'tempfile'

class DhRubyTest < Gem2DebTestCase

  one_time_setup do
    self.instance = Gem2Deb::DhRuby.new
    instance.verbose = false

    build(SIMPLE_GEM, SIMPLE_GEM_DIRNAME)
    build(SIMPLE_PROGRAM, SIMPLE_PROGRAM_DIRNAME)
    build(SIMPLE_EXTENSION, SIMPLE_EXTENSION_DIRNAME)
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
    should 'install manpages at /usr/share/man' do
      assert_installed SIMPLE_PROGRAM_DIRNAME, 'ruby-simpleprogram', '/usr/share/man/man1/simpleprogram.1'
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
  end

  protected

  def assert_installed(gem_dirname, package, path)
    assert_file_exists installed_file_path(gem_dirname, package, path)
  end

  def read_installed_file(gem_dirname, package, path)
    File.read(installed_file_path(gem_dirname, package, path))
  end

  def installed_file_path(gem_dirname, package, path)
    File.join(self.class.tmpdir, gem_dirname, 'debian', package, path)
  end

  def self.build(gem, source_package)
    package_path = File.join(tmpdir, source_package)
    tarball =  package_path + '.tar.gz'
    Gem2Deb::Gem2Tgz.convert!(gem, tarball)
    Gem2Deb::DhMakeRuby.new(tarball).build

    silence_stream(STDOUT) do
      Dir.chdir(package_path) do
        instance.clean
        instance.configure
        instance.build
        binary_packages = `dh_listpackages`.split
        binary_packages.each do |pkg|
          instance.install File.join(package_path, 'debian', pkg)
        end
      end
    end
  end

  def self.silence_stream(stream)
    orig_stream = stream.clone
    begin
      Tempfile.open('gem2deb-tests-stdoud') do |f|
        stream.reopen(f)
        yield
      end
    ensure
      stream.reopen(orig_stream)
    end
  end

end
