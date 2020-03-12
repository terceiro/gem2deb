require_relative '../test_helper'
require 'gem2deb/gem2tgz'
require 'gem2deb/dh_make_ruby'

class DhMakeRubyTest < Gem2DebTestCase

  DEBIANIZED_SIMPLE_GEM       = File.join(tmpdir, 'ruby-' + SIMPLE_GEM_DIRNAME)
  SIMPLE_GEM_UPSTREAM_TARBALL = File.join(tmpdir, SIMPLE_GEM_DIRNAME + '.tar.gz')
  one_time_setup do
    # generate tarball
    Gem2Deb::Gem2Tgz.convert!(SIMPLE_GEM, SIMPLE_GEM_UPSTREAM_TARBALL)

    Gem2Deb::DhMakeRuby.new(SIMPLE_GEM_UPSTREAM_TARBALL).build
  end

  should 'use ruby-* package name by default' do
    assert_equal 'ruby-simplegem', Gem2Deb::DhMakeRuby.new(SIMPLE_GEM_UPSTREAM_TARBALL).source_package_name
  end

  should 'use existing package name if present' do
    dmr = Gem2Deb::DhMakeRuby.new(KILLERAPP_DIR)
    assert_equal 'killerapp', dmr.source_package_name
  end

  should 'be able to specify a package name' do
    assert_equal 'xyz', Gem2Deb::DhMakeRuby.new(SIMPLE_GEM_UPSTREAM_TARBALL, :source_package_name => 'xyz').source_package_name
  end

  should 'replace underscores with dashes in source package name' do
    assert_equal 'ruby-foo-bar', Gem2Deb::DhMakeRuby.new('foo_bar-0.0.1.tar.gz').source_package_name
  end

  should 'duplicate "ruby" in the name of a package' do
    assert_equal 'ruby-ruby-foo', Gem2Deb::DhMakeRuby.new('ruby_foo-1.2.3.tar.gz').source_package_name
    assert_equal 'ruby-foo-ruby', Gem2Deb::DhMakeRuby.new('foo_ruby-1.2.3.tar.gz').source_package_name
  end

  should 'properly convert CFPropertyList to debian package name' do
    assert_equal 'ruby-cfpropertylist', Gem2Deb::DhMakeRuby.new('CFPropertyList-1.2.3.tar.gz').source_package_name
  end

  should 'properly convert Fancy_Package to debian package name' do
    assert_equal 'ruby-fancy-package', Gem2Deb::DhMakeRuby.new('Fancy_Package-1.2.3.tar.gz').source_package_name
  end

  should 'use #nnnn if no ITP bug exists' do
    @dh_make_ruby = Gem2Deb::DhMakeRuby.new('ruby_foo-1.2.3.tar.gz', :do_wnpp_check => true)
    @dh_make_ruby.expects(:wnpp_check).returns('').once
    assert_equal @dh_make_ruby.itp_bug, '#nnnn'
  end

  should 'use ITP bug if it exists' do
    @dh_make_ruby = Gem2Deb::DhMakeRuby.new('ruby_foo-1.2.3.tar.gz', :do_wnpp_check => true)
    @dh_make_ruby.expects(:wnpp_check).returns('(ITP - #42) http://bugs.debian.org/42 ruby-foo').once
    assert_equal @dh_make_ruby.itp_bug, '#42'
  end

  should 'not make libraries depend on ruby' do
    dh_make_ruby = Gem2Deb::DhMakeRuby.new(SIMPLE_GEM_SOURCE)
    assert_not_include dh_make_ruby.binary_package.dependencies, 'ruby'
  end

  should 'make programs depend on ruby' do
    dh_make_ruby = Gem2Deb::DhMakeRuby.new(SIMPLE_PROGRAM_SOURCE)
    assert_include dh_make_ruby.binary_package.dependencies, 'ruby'
  end

  context 'simple gem' do
    %w[
      debian/control
      debian/rules
      debian/copyright
      debian/changelog
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

  should 'produce debian/copyright with FIXMEs in it' do
    copyright = File.read(File.join(DEBIANIZED_SIMPLE_GEM, 'debian/copyright'))
    assert copyright =~ /FIXME/
  end

  DEBIANIZED_SIMPLE_EXTENSION       = File.join(tmpdir, SIMPLE_EXTENSION_DIRNAME)
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
      assert_match %r/gemwatch\.debian\.net\/Fancy_Package/, File.read(File.join(tmpdir, 'ruby-fancy-package-0.0.1/debian/watch'))
    end
    should 'use actual upstream name in debian/copyright' do
      assert_match %r/Upstream-Name: Fancy_Package/, File.read(File.join(tmpdir, 'ruby-fancy-package-0.0.1/debian/copyright'))
    end
  end

  context 'dh-make-ruby --overwrite' do
    setup do
      @pwd = Dir.pwd
      @tmpdir = Dir.mktmpdir
      Dir.chdir @tmpdir
      Dir.mkdir('debian')
      @dmr = Gem2Deb::DhMakeRuby.new('.')
    end
    teardown do
      Dir.chdir @pwd
      FileUtils.rm_rf @tmpdir
    end
    should 'create file' do
      @dmr.overwrite = false
      @dmr.maybe_create('debian/rules') { |f| f.puts('hello') }
      assert_file_exists 'debian/rules'
    end
    should 'overwrite if overwrite is true' do
      @dmr.overwrite = true
      @dmr.maybe_create('debian/rules') { |f| f.puts('hello 1') }
      @dmr.maybe_create('debian/rules') { |f| f.puts('hello 2') }
      assert_equal 'hello 2', File.read('debian/rules').strip
    end
    should 'not overwrite if overwrite is false' do
      @dmr.overwrite = false
      @dmr.maybe_create('debian/rules') { |f| f.puts('hello 1') }
      @dmr.maybe_create('debian/rules') { |f| f.puts('hello 2') }
      assert_equal 'hello 1', File.read('debian/rules').strip
    end
    should 'never overwrite debian/copyright' do
      @dmr.overwrite = true
      @dmr.maybe_create('debian/copyright') { |f| f.puts('hello 1') }
      @dmr.maybe_create('debian/copyright') { |f| f.puts('hello 2') }
      assert_equal 'hello 1', File.read('debian/copyright').strip
    end

  end

  protected

  def packages
    `grep-dctrl -n -s Package -F Package '' debian/control`.split
  end

end

