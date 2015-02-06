require_relative '../test_helper'
require 'gem2deb/gem2tgz'
require 'gem2deb/dh_make_ruby'

class DhMakeRubyTest < Gem2DebTestCase

  DEBIANIZED_SIMPLE_GEM       = File.join(tmpdir, 'ruby-' + SIMPLE_GEM_DIRNAME)
  SIMPLE_GEM_UPSTREAM_TARBALL = DEBIANIZED_SIMPLE_GEM + '.tar.gz'
  one_time_setup do
    # generate tarball
    Gem2Deb::Gem2Tgz.convert!(SIMPLE_GEM, SIMPLE_GEM_UPSTREAM_TARBALL)

    Gem2Deb::DhMakeRuby.new(SIMPLE_GEM_UPSTREAM_TARBALL).build
  end

  should 'use ruby-* package name by default' do
    assert_equal 'ruby-simplegem', Gem2Deb::DhMakeRuby.new(SIMPLE_GEM_UPSTREAM_TARBALL).source_package_name
  end

  should 'be able to specify a package name' do
    assert_equal 'xyz', Gem2Deb::DhMakeRuby.new(SIMPLE_GEM_UPSTREAM_TARBALL, :source_package_name => 'xyz').source_package_name
  end

  should 'replace underscores with dashes in source package name' do
    assert_equal 'ruby-foo-bar', Gem2Deb::DhMakeRuby.new('foo_bar-0.0.1.tar.gz').source_package_name
  end

  should 'not duplicate "ruby" in the name of a package' do
    assert_equal 'ruby-foo', Gem2Deb::DhMakeRuby.new('ruby_foo-1.2.3.tar.gz').source_package_name
    assert_equal 'ruby-foo', Gem2Deb::DhMakeRuby.new('foo_ruby-1.2.3.tar.gz').source_package_name
  end

  should 'use #nnnn if no ITP bug exists' do
      @dh_make_ruby = Gem2Deb::DhMakeRuby.new('ruby_foo-1.2.3.tar.gz', :do_wnpp_check => true)
      @dh_make_ruby.stubs(:wnpp_check).returns('')
      assert_equal @dh_make_ruby.itp_bug, '#nnnn'
  end

  should 'use ITP bug if it exists' do
      @dh_make_ruby = Gem2Deb::DhMakeRuby.new('ruby_foo-1.2.3.tar.gz', :do_wnpp_check => true)
      @dh_make_ruby.stubs(:wnpp_check).returns('(ITP - #42) http://bugs.debian.org/42 ruby-foo')
      assert_equal @dh_make_ruby.itp_bug, '#42'
  end

  context 'simple gem' do
    %w[
      debian/control
      debian/rules
      debian/copyright
      debian/changelog
      debian/compat
      debian/watch
      debian/source/format
    ].each do |file|
      filename = File.join(DEBIANIZED_SIMPLE_GEM, file)
      should "create #{file}" do
        assert_file_exists filename
      end
      should "create non-empty #{file} file" do
        assert !File.zero?(filename), "#{filename} expected NOT to be empty"
      end
    end
  end

  DEBIANIZED_SIMPLE_EXTENSION       = File.join(tmpdir, 'ruby-' + SIMPLE_EXTENSION_DIRNAME)
  SIMPLE_EXTENSION_UPSTREAM_TARBALL = DEBIANIZED_SIMPLE_EXTENSION + '.tar.gz'
  one_time_setup do
   Gem2Deb::Gem2Tgz.convert!(SIMPLE_EXTENSION, SIMPLE_EXTENSION_UPSTREAM_TARBALL)
   Gem2Deb::DhMakeRuby.new(SIMPLE_EXTENSION_UPSTREAM_TARBALL).build
  end

  DEBIANIZED_SIMPLE_PROGRAM       = File.join(tmpdir, SIMPLE_PROGRAM_DIRNAME)
  SIMPLE_PROGRAM_UPSTREAM_TARBALL = DEBIANIZED_SIMPLE_PROGRAM + '.tar.gz'
  one_time_setup do
    # generate tarball
    Gem2Deb::Gem2Tgz.convert!(SIMPLE_PROGRAM, SIMPLE_PROGRAM_UPSTREAM_TARBALL)

    pkg = Gem2Deb::DhMakeRuby.new(SIMPLE_PROGRAM_UPSTREAM_TARBALL, :source_package_name => 'simpleprogram')
    pkg.build
  end
  context 'simple program' do
    should "create manpages file for dh_installman" do
      filename = File.join(DEBIANIZED_SIMPLE_PROGRAM, "debian/simpleprogram.manpages")
      assert_file_exists filename
    end
  end

  TEST_SIMPLE_GIT = File.join(tmpdir, 'simplegit')
  one_time_setup do
    FileUtils.cp_r(SIMPLE_GIT, TEST_SIMPLE_GIT)
    Gem2Deb::DhMakeRuby.new(TEST_SIMPLE_GIT).build
  end

  context 'running dh-make-ruby against a directory' do
    should 'get the package name correctly' do
      assert_equal ['ruby-simplegit'], Dir.chdir(TEST_SIMPLE_GIT) { packages }
    end
    should 'get the version name correctly' do
      assert_equal 'Version: 0.0.1-1', Dir.chdir(TEST_SIMPLE_GIT) { `dpkg-parsechangelog | grep Version:`.strip }
    end
    should 'create debian/control' do
      assert_file_exists File.join(TEST_SIMPLE_GIT, 'debian/control')
    end
    should 'create debian/rules' do
      assert_file_exists File.join(TEST_SIMPLE_GIT, 'debian/rules')
    end
  end

  FANCY_PACKAGE_TARBALL = File.join(tmpdir, 'fancy-package-0.0.1.tar.gz')
  one_time_setup do
    Gem2Deb::Gem2Tgz.convert!(FANCY_PACKAGE, FANCY_PACKAGE_TARBALL)
    $__fancy_package_dh_make_ruby = Gem2Deb::DhMakeRuby.new(FANCY_PACKAGE_TARBALL)
    $__fancy_package_dh_make_ruby.build
  end
  context 'a package with a fancy name that is not a valid Debian package name' do
    should 'use upstream name from metadata' do
      assert_equal 'Fancy_Package', $__fancy_package_dh_make_ruby.gem_name
    end
    should 'use actual upstream name in debian/watch' do
      assert_match /gemwatch\/Fancy_Package/, File.read(File.join(tmpdir, 'ruby-fancy-package-0.0.1/debian/watch'))
    end
    should 'use actual upstream name in debian/copyright' do
      assert_match /Upstream-Name: Fancy_Package/, File.read(File.join(tmpdir, 'ruby-fancy-package-0.0.1/debian/copyright'))
    end
  end

  context 'dependencies' do
    setup do
      text = File.read(File.join(DEBIANIZED_SIMPLE_GEM, 'debian/control'))
      line = text.lines.find { |l| l =~ /^Depends: / }.strip
      @dependencies = line.gsub(/^Depends:\s*/, '').split(/\s*,\s*/)
    end
    should 'get simple dependency' do
      assert_include @dependencies, 'ruby-dep'
    end
    should 'get dependency with an exact version' do
      assert_include @dependencies, 'ruby-depwithversion (= 1.0)'
    end
    should 'get version with spermy' do
      assert_include @dependencies, 'ruby-depwithspermy (>= 1.0)'
    end
    should 'get version with >' do
      assert_include @dependencies, 'ruby-depwithgt (>> 1.0)'
    end
    should 'get version with two requirements' do
      assert_include @dependencies, 'ruby-depwith2versions (>= 1.0)'
      assert_include @dependencies, 'ruby-depwith2versions (<< 2.0)'
    end
  end

  protected

  def packages
    `dh_listpackages`.split
  end

end

