require_relative '../test_helper'
require 'gem2deb/package_name_mapping'

class PackageNameMappingTest < Gem2DebTestCase

  context 'converting gem name to package name without a cache' do
    {
      'foo' => 'ruby-foo',
      'foo-bar_baz' => 'ruby-foo-bar-baz',
    }.each do |input,output|
      setup do
        Gem2Deb::PackageNameMapping.any_instance.stubs(:update!)
        @mapping = Gem2Deb::PackageNameMapping.new
      end
      should "convert #{input} to #{output}" do
        assert_equal output, @mapping[input]
      end
    end
  end

  context 'using data from installed packages' do
    setup do
      @mapping = Gem2Deb::PackageNameMapping.new(false)
    end
    should 'have data for mocha' do
      assert_include @mapping.data.keys, "mocha"
    end
  end

end
