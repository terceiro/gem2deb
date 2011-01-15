require 'test/helper'
require 'gem2deb/dhruby'

class DhRubyTest < Gem2DebTestCase

  one_time_setup do
    self.instance = Gem2Deb::DhRuby.new
    instance.verbose = false

    build(SIMPLE_GEM, SIMPLE_GEM_DIRNAME)
    #FIXME build(SIMPLE_PROGRAM, SIMPLE_PROGRAM_DIRNAME)
    #FIXME build(SIMPLE_NATIVE_EXTENSION, SIMPLE_NATIVE_EXTENSION_DIRNAME)
  end

  context 'installing simplegem' do
    should 'install pure-Ruby code' do
      assert_installed SIMPLE_GEM_DIRNAME, 'ruby-simplegem', '/usr/lib/ruby/vendor_ruby/simplegem.rb'
    end
  end

  context 'installing Ruby program' do
    should 'install programs at /usr/bin' # FIXME
    should 'install manpages at /usr/share/man' # FIXME
  end

  context 'installing native extension' do
    should 'install native extension for ruby1.8' # FIXME
    should 'install native extension for ruby1.9.1' # FIXME
  end

  protected

  def assert_installed(gem_dirname, package, path)
    assert_file_exists File.join(self.class.tmpdir, gem_dirname, 'debian', package, path)
  end

  def self.build(gem, source_package)
    package_path = File.join(tmpdir, source_package)
    tarball =  package_path + '.tar.gz'
    Gem2Deb::Gem2Tgz.convert!(gem, tarball)
    Gem2Deb::DhMakeRuby.new(tarball).build

    Dir.chdir(package_path) do
      instance.clean
      instance.configure
      instance.build
      binary_packages = read_debian_control.map { |stanza| stanza['Package'] }.compact
      binary_packages.each do |pkg|
        instance.install File.join(package_path, 'debian', pkg)
      end
    end
  end

end
