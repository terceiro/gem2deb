require 'test/helper'
require 'gem2deb/dh-make-ruby'

class DhMakeRubyTest < Gem2DebTestCase

  DH_MAKE_RUBY_TMP_DIR        = File.join(TMP_DIR, 'dh-make-ruby')
  DEBIANIZED_SIMPLE_GEM       = File.join(DH_MAKE_RUBY_TMP_DIR, SIMPLE_GEM_DIRNAME)
  SIMPLE_GEM_UPSTREAM_TARBALL = DEBIANIZED_SIMPLE_GEM + '.tar.gz'
  one_time_setup do
    FileUtils.mkdir_p(DH_MAKE_RUBY_TMP_DIR)
    # generate tarball
    Gem2Deb::Gem2Tgz.convert!(SIMPLE_GEM, SIMPLE_GEM_UPSTREAM_TARBALL)

    self.instance = Gem2Deb::DhMakeRuby.new(SIMPLE_GEM_UPSTREAM_TARBALL)
    self.instance.build
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
      should "create #{file}" do
        assert_file_exists File.join(DEBIANIZED_SIMPLE_GEM, file)
      end
    end
  end

end

