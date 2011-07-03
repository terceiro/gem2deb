require 'test/unit'
require 'simpleextension_with_name_clash'

class SimpleExtensionWithNameClashTest < Test::Unit::TestCase
  def test_simple
    assert_equal 42, SimpleExtensionWithNameClash.answer42
  end
end
