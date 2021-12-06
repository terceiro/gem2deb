require_relative '../test_helper'
require 'gem2deb/package_name_mapping'
require 'stringio'

class PackageNameMappingTest < Gem2DebTestCase

  context 'converting gem name to package name without a cache' do
    {
      'foo' => 'ruby-foo',
      'foo-bar_baz' => 'ruby-foo-bar-baz',
    }.each do |input,output|
      setup do
        Gem2Deb::PackageNameMapping.any_instance.stubs(:get_data_from_archive!)
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

  should 'strip architecture qualifier off package names' do
    IO.stubs(:popen).returns(StringIO.new("ruby-foo:amd64: /usr/share/rubygems-integration/2.7.0/specifications/foo-1.0.0.gemspec\nruby-bar: /usr/share/rubygems-integration/2.7.0/specifications/bar-2.0.0.gemspec\n"))
    mapping = Gem2Deb::PackageNameMapping.new(false)
    assert_equal "ruby-foo", mapping.data["foo"]
    assert_equal "ruby-bar", mapping.data["bar"]
  end

end
