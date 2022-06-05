require_relative '../test_helper'

class Gem2DebTest < Gem2DebTestCase

  def self.build(gem)
    FileUtils.cp gem, tmpdir
    gem = File.basename(gem)
    Dir.chdir(tmpdir) do
      cmd = "gem2deb -d #{gem}"
      run_command(cmd)
    end
  end

  Dir.glob('test/sample/*/pkg/*.gem').each do |gem|
    puts "Building #{gem} ..."
    self.build(gem)
    should "build #{gem} correcly" do
      package_name = 'ruby-' + File.basename(File.dirname(File.dirname(gem))).gsub('_', '-').downcase
      binary_packages = File.join(self.class.tmpdir, "#{package_name}_*.deb")
      packages = Dir.glob(binary_packages)
      assert !packages.empty?, "building #{gem} produced no binary packages! (expected to find #{binary_packages})"
    end
  end

  should 'install executables for altbindir' do
    assert_match '/usr/bin/altbindir', `dpkg --contents #{self.class.tmpdir}/ruby-altbindir*.deb`
  end

  should 'not install non-listed executables from altbindir' do
    assert_no_match %r{/usr/bin/dont-install}, `dpkg --contents #{self.class.tmpdir}/ruby-altbindir*.deb`
  end

  def self.build_tree(directory)
    FileUtils.cp_r(directory, tmpdir)
    dir = File.join(tmpdir, File.basename(directory))
    yield(dir)
    puts "Building #{directory} ..."
    Dir.chdir(dir) do
      run_command('fakeroot debian/rules binary')
    end
  end

  self.build_tree('test/sample/examples') do |dir|

    should 'not compress *.rb files installed as examples' do
      assert_no_file_exists "#{dir}/debian/ruby-examples/usr/share/doc/ruby-examples/examples/test.rb.gz"
      assert_file_exists "#{dir}/debian/ruby-examples/usr/share/doc/ruby-examples/examples/test.rb"
    end

    should 'install CHANGELOG.rdoc as upstream changelog' do
      changelog = "#{dir}/debian/ruby-examples/usr/share/doc/ruby-examples/changelog.gz"
      assert_file_exists changelog
    end

  end

  self.build_tree('test/sample/multibinary') do |dir|
    context "multibinary source package" do
      should "install foo in ruby-foo" do
        assert_file_exists "#{dir}/debian/ruby-foo/usr/bin/foo"
      end
      should 'install foo.rb in ruby-foo' do
        assert_file_exists "#{dir}/debian/ruby-foo/usr/lib/ruby/vendor_ruby/foo.rb"
      end
      should 'install bar in ruby-bar' do
        assert_file_exists "#{dir}/debian/ruby-bar/usr/bin/bar"
      end
      should 'install bar.rb ruby-bar' do
        assert_file_exists "#{dir}/debian/ruby-bar/usr/lib/ruby/vendor_ruby/bar.rb"
      end
      should 'support installing upstream CHANGELOG in multibinary package' do
        assert_file_exists "#{dir}/debian/ruby-bar/usr/share/doc/ruby-bar/changelog.gz"
      end

      should 'support native extensions' do
        assert Dir.glob("#{dir}/debian/ruby-baz/**/baz.so").size > 0, 'baz.so not found!!!'
      end

      should 'inject dependency on ruby (>= something)' do
        deps = File.readlines("#{dir}/debian/ruby-baz/DEBIAN/control").find do |line|
          line =~ /^Depends:\s*/
        end.sub(/^Depends:\s*/, '').split(/\s*,\s*/)
        assert deps.any? { |dep| dep =~ /ruby \(>= [^)]+\)/}, "#{deps.inspect} expected to include 'ruby (>= something)'"
      end
    end
  end

  self.build_tree('test/sample/simpleextension_dh_auto_install_destdir') do |dir|
    should 'honor DH_RUBY_USE_DH_AUTO_INSTALL_DESTDIR when building extensions' do
      assert Dir.glob("#{dir}/debian/tmp/**/*.so").size > 0, 'no .so files found in debian/tmp/'
    end
  end

  self.build_tree('test/sample/install_as_gem') do |dir|
    context 'using --gem-install' do
      should 'install' do
        assert Dir.glob("#{dir}/debian/*/**/*.so").size > 0 , '.so file is installed'
      end
    end
  end

  %w[
    13
    14
  ].each do |level|
    self.build_tree("test/sample/simplegem#{level}") do |dir|
      context "compatiblity level #{level}" do
        should 'work' do
          assert Dir.glob("#{dir}/debian/*/**/*.rb").size > 0
        end
      end
    end
  end


end
