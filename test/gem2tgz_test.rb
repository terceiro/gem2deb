require 'test/helper'
require 'yaml'
require 'rubygems'

require 'gem2deb/gem2tgz'

class Gem2TgzTest < Gem2TgzTestCase

  SIMPLE_GEM            = File.join(File.dirname(__FILE__), 'sample/simplegem/pkg/simplegem-0.0.1.gem')
  SIMPLE_GEM_TARBALL    = File.join(File.dirname(__FILE__), 'tmp/simplegem-0.0.1.tar.gz')
  SIMPLE_GEM_TARGET_DIR = File.join(File.dirname(__FILE__), 'tmp/simplegem-0.0.1')

  context 'converting a simple gem' do
    setup do
      Gem2Deb::Gem2Tgz.convert!(SIMPLE_GEM, SIMPLE_GEM_TARBALL)
    end

    should 'create tarball' do
      assert_file_exists SIMPLE_GEM_TARBALL
    end
    should 'include the contents of the gem in the tarball' do
      assert_contained_in_tarball SIMPLE_GEM_TARBALL, 'simplegem-0.0.1/lib/simplegem.rb'
    end
    should 'not include data.tar.gz' do
      assert_not_contained_in_tarball SIMPLE_GEM_TARBALL, 'simplegem-0.0.1/data.tar.gz'
    end
    should 'not include metadata.gz' do
      assert_not_contained_in_tarball SIMPLE_GEM_TARBALL, 'simplegem-0.0.1/metadata.gz'
    end
    should 'not leave temporary directory after creating tarball' do
      assert_no_file_exists SIMPLE_GEM_TARGET_DIR
    end
    should 'create metadata.yml' do
      unpack(SIMPLE_GEM_TARBALL) do
        assert_file_exists 'simplegem-0.0.1/metadata.yml'
      end
    end
    context 'looking inside metadata.yml' do
      setup do
        @gemspec = unpack(SIMPLE_GEM_TARBALL) do
          YAML.load_file('simplegem-0.0.1/metadata.yml')
        end
      end
      should 'be valid gemspec' do
        assert_kind_of Gem::Specification, @gemspec
      end
      should "be simplegem's spec" do
        assert_equal 'simplegem', @gemspec.name
      end
    end
  end

end
