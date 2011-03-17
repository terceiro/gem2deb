require 'test_helper'
require 'gem2deb/metadata'
require 'yaml'

class MetaDataTest < Gem2DebTestCase

  {
    'simpleextension'         => true,
    'simpleextension_in_root' => true,
    'simplegem'               => false,
    'simplemixed'             => true,
    'simpleprogram'           => false,
    'simpletgz'               => false,
  }.each do |source_package, has_extensions|
    should "correctly detect native extensions for #{source_package}" do
      assert_equal has_extensions, Gem2Deb::Metadata.new(File.join('test/sample', source_package)).has_native_extensions?
    end
  end

  def setup
    FileUtils.mkdir_p('test/tmp')
    @metadata = Gem2Deb::Metadata.new('test/tmp')
  end

  def teardown
    FileUtils.rmdir('test/tmp')
  end

  context 'without gemspec' do
    should 'have no homepage' do
      assert_nil @metadata.homepage
    end
    should 'have no short description' do
      assert_nil @metadata.short_description
    end
    should 'have no long description' do
      assert_nil @metadata.long_description
    end
    should 'have no dependencies' do
      assert_equal [], @metadata.dependencies
    end
    should 'have no test files' do
      assert_equal [], @metadata.test_files
    end
  end

  context 'with gemspec' do
    setup do
      @gemspec = mock
      @metadata.stubs(:gemspec).returns(@gemspec)
    end

    should 'obtain homepage from gemspec' do
      @gemspec.stubs(:homepage).returns('http://www.debian.org/')
      assert_equal 'http://www.debian.org/', @metadata.homepage
    end

    should 'obtain short description from gemspec' do
      @gemspec.stubs(:summary).returns('This library does stuff')
      assert_equal 'This library does stuff', @metadata.short_description
    end

    should 'obtain long detect from gemspec' do
      @gemspec.stubs(:description).returns('This is the long description, bla bla bla')
      assert_equal 'This is the long description, bla bla bla', @metadata.long_description
    end

    should 'obtain dependencies list from gemspec' do
      @gemspec.stubs(:dependencies).returns(['gem1', 'gem2'])
      assert_equal ['gem1', 'gem2'], @metadata.dependencies
    end

    should 'obtain test files list from gemspec' do
      @gemspec.stubs(:test_files).returns(['test/class1_test.rb', 'test/class2_test.rb'])
      assert_equal ['test/class1_test.rb', 'test/class2_test.rb'], @metadata.test_files
    end

  end

end

