require_relative '../test_helper'
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
  end

  def teardown
    FileUtils.rmdir('test/tmp')
  end

  context 'without gemspec' do
    setup do
      @metadata = Gem2Deb::Metadata.new('test/tmp')
    end
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
    should 'provide a gem name from source dir' do
      assert_equal 'tmp', @metadata.name
    end
    should 'provide a fallback version number' do
      assert_not_nil @metadata.version
    end
    should 'read version number from source dir name when available' do
      @metadata.stubs(:source_dir).returns('/tmp/package-1.2.3')
      assert_equal 'package', @metadata.name
      assert_equal '1.2.3', @metadata.version
    end
  end

  context 'with gemspec' do
    setup do
      @gemspec = mock
      @metadata = Gem2Deb::Metadata.new('test/tmp')
      @metadata.stubs(:gemspec).returns(@gemspec)
    end

    should 'obtain gem name from gemspec' do
      @gemspec.stubs(:name).returns('weird')
      assert_equal 'weird', @metadata.name
    end

    should 'obtain gem version from gemspec' do
      @gemspec.stubs(:version).returns(Gem::Version.new('0.0.1'))
      assert_equal '0.0.1', @metadata.version
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
      @gemspec.stubs(:test_files).returns(['test/class1_test.rb', 'test/class2_test.rb', 'test/not_a_test.txt'])
      assert_equal ['test/class1_test.rb', 'test/class2_test.rb'], @metadata.test_files
    end

  end

  context 'on multi-binary source packages' do

    setup do
      Dir.chdir('test/sample/multibinary') do
        @metadata = Gem2Deb::Metadata.new('baz')
      end
    end

    should 'get the right path for extensions without a gemspec' do
      assert_equal ['baz/ext/baz/extconf.rb'], @metadata.native_extensions
    end

    should 'get the right path to extensions with a gemspec' do
      @gemspec = mock
      @metadata.stubs(:gemspec).returns(@gemspec)
      @gemspec.expects(:extensions).returns(['path/to/extconf.rb'])
      assert_equal ['baz/path/to/extconf.rb'], @metadata.native_extensions
    end

  end

end

