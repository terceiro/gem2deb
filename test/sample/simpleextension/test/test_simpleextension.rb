require 'test/unit'
require 'simpleextension'

class SimpleExtensionTest < Test::Unit::TestCase
  def test_answer
    assert_equal(42, SimpleExtension.answer42) 
  end
  def test_const
    assert_equal("Hello World", SimpleExtension::Hello_world)
  end
end
