require_relative '../test_helper'
require 'gem2deb/source'

class SourceTest < Gem2DebTestCase

  context "selecting package layout" do

    setup do
      @source = Gem2Deb::Source.new
    end

    should 'default to single-binary' do
      debian_control << 'Package: ruby-foo'
      debian_control << 'Package: ruby-bar'
      ruby_foo = { :binary_package => 'ruby-foo', :root => '.' }
      assert_equal [ruby_foo], @source.send(:packages)
    end

    should 'ignore packages without X-DhRuby-Root when one of them has it' do
      debian_control << 'Package: ruby-foo'
      debian_control << 'Package: ruby-bar'
      debian_control << 'X-DhRuby-Root: bar'

      ruby_bar = { :binary_package => 'ruby-bar', :root => 'bar' }
      assert_equal [ruby_bar], @source.send(:packages)
    end

    should 'detect multibinary' do
      debian_control << 'Package: ruby-foo'
      debian_control << 'X-DhRuby-Root: foo'
      debian_control << 'Package: ruby-bar'
      debian_control << 'X-DhRuby-Root: bar'
      ruby_foo = { :binary_package => 'ruby-foo', :root => 'foo' }
      ruby_bar = { :binary_package => 'ruby-bar', :root => 'bar' }
      assert_equal [ruby_foo, ruby_bar], @source.send(:packages)
    end

  end

end

