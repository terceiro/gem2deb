require_relative '../test_helper'
require 'yaml'
require 'rubygems'

require 'gem2deb/gem2tgz'

class Gem2TgzTest < Gem2DebTestCase

  SIMPLE_GEM_TARBALL    = File.join(tmpdir,    "#{SIMPLE_GEM_DIRNAME}.tar.gz")
  SIMPLE_TGZ_TARBALL    = File.join(tmpdir,    "#{SIMPLE_TGZ_DIRNAME}.tar.gz")

  should 'convert using a new instance when converting through the class' do
    gem2tgz = mock
    gem2tgz.expects(:convert!)
    Gem2Deb::Gem2Tgz.expects(:new).with(SIMPLE_GEM, SIMPLE_GEM_TARBALL).returns(gem2tgz)
    Gem2Deb::Gem2Tgz.convert!(SIMPLE_GEM, SIMPLE_GEM_TARBALL)
  end

  class << self
    attr_accessor :instance
  end
  def instance
    self.class.instance
  end


  one_time_setup do
    self.instance = Gem2Deb::Gem2Tgz.new(SIMPLE_GEM, SIMPLE_GEM_TARBALL)
    self.instance.convert!
  end

  context 'converting a simple gem' do
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
      assert_no_file_exists instance.target_dir
    end
    should 'not leave metadata.yml in the tarball' do
      assert_not_contained_in_tarball SIMPLE_GEM_TARBALL, 'simplegem-0.0.1/metadata.yml'
    end
    should 'create gemspec' do
      unpack(SIMPLE_GEM_TARBALL) do
        assert_file_exists 'simplegem-0.0.1/simplegem.gemspec'
      end
    end
    should 'not include checksums.yaml.gz' do
      assert_not_contained_in_tarball SIMPLE_GEM_TARBALL, 'simplegem-0.0.1/checksums.yaml.gz'
    end
    context 'looking inside generated gemspec' do
      setup do
        @gemspec = unpack(SIMPLE_GEM_TARBALL) do
          Gem::Specification.load('simplegem-0.0.1/simplegem.gemspec')
        end
      end
      should 'be a valid gemspec' do
        assert_kind_of Gem::Specification, @gemspec
      end
      should "be simplegem's spec" do
        assert_equal 'simplegem', @gemspec.name
      end
    end
  end

  context('tgz package') do
    setup do
      @tgz = Gem2Deb::Gem2Tgz.new(SIMPLE_TGZ, SIMPLE_TGZ_TARBALL)
      @tgz.convert!
    end
    should 'create tarball' do
      assert_file_exists SIMPLE_TGZ_TARBALL
    end
    should 'include the contents of the tgz in the tarball' do
      assert_contained_in_tarball SIMPLE_TGZ_TARBALL, 'simpletgz-0.0.1/lib/simpletgz.rb'
    end
  end

  should 'not mess with the full path' do
    testdir = File.join(tmpdir, 'Downloads') # uppercase
    FileUtils.mkdir_p(testdir)
    FileUtils.cp(SIMPLE_GEM, testdir)
    gem = File.join(testdir, File.basename(SIMPLE_GEM))
    tarball = gem.gsub('.gem', '.tar.gz')

    Gem2Deb::Gem2Tgz.new(gem).convert!
    assert File.exist?(tarball)
  end

end
