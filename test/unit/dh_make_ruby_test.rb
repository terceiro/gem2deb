require 'test_helper'
require 'gem2deb/gem2tgz'
require 'gem2deb/dh_make_ruby'

class DhMakeRubyTest < Gem2DebTestCase

  DEBIANIZED_SIMPLE_GEM       = File.join(tmpdir, SIMPLE_GEM_DIRNAME)
  SIMPLE_GEM_UPSTREAM_TARBALL = DEBIANIZED_SIMPLE_GEM + '.tar.gz'
  one_time_setup do
    # generate tarball
    Gem2Deb::Gem2Tgz.convert!(SIMPLE_GEM, SIMPLE_GEM_UPSTREAM_TARBALL)

    Gem2Deb::DhMakeRuby.new(SIMPLE_GEM_UPSTREAM_TARBALL).build
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

  DEBIANIZED_SIMPLE_EXTENSION       = File.join(tmpdir, SIMPLE_EXTENSION_DIRNAME)
  SIMPLE_EXTENSION_UPSTREAM_TARBALL = DEBIANIZED_SIMPLE_EXTENSION + '.tar.gz'
  one_time_setup do
   Gem2Deb::Gem2Tgz.convert!(SIMPLE_EXTENSION, SIMPLE_EXTENSION_UPSTREAM_TARBALL)
   Gem2Deb::DhMakeRuby.new(SIMPLE_EXTENSION_UPSTREAM_TARBALL).build
  end

  context 'native extension' do
    should 'generate one package for ruby1.8' do
      Dir.chdir(DEBIANIZED_SIMPLE_EXTENSION) do
        assert(packages.include?('ruby1.8-simpleextension'), "Package ruby1.8-simpleextension not created")
      end
    end
    should 'generate one package for ruby1.9.1' do
      Dir.chdir(DEBIANIZED_SIMPLE_EXTENSION) do
        assert(packages.include?('ruby1.9.1-simpleextension'), "Package ruby1.9.1-simpleextension not created")
      end
    end
  end

  DEBIANIZED_SIMPLE_PROGRAM       = File.join(tmpdir, SIMPLE_PROGRAM_DIRNAME)
  SIMPLE_PROGRAM_UPSTREAM_TARBALL = DEBIANIZED_SIMPLE_PROGRAM + '.tar.gz'
  one_time_setup do
    # generate tarball
    Gem2Deb::Gem2Tgz.convert!(SIMPLE_PROGRAM, SIMPLE_PROGRAM_UPSTREAM_TARBALL)

    pkg = Gem2Deb::DhMakeRuby.new(SIMPLE_PROGRAM_UPSTREAM_TARBALL)
    pkg.build
    GEM_NAME = pkg.gem_name
  end
  context 'simple program' do
    should "create manpages file for dh_installman" do
      filename = File.join(DEBIANIZED_SIMPLE_PROGRAM, "debian/ruby-#{GEM_NAME}.manpages")
      assert_file_exists filename
    end
  end

  protected

  def packages
    `dh_listpackages`.split
  end

end

