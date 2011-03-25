require 'test_helper'
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

  protected

  def packages
    `dh_listpackages`.split
  end

end

