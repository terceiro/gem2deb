require 'test/unit'
require 'simplesetuprb'

class SimpleSetuprbTest < Test::Unit::TestCase
  def test_answer
    assert_equal(42, SimpleSetuprb.answer42) 
  end
  def test_const
    assert_equal("Hello World", SimpleSetuprb::Hello_world)
  end

  def test_generated
    assert_equal(:generated, SimpleSetuprb::generated_function)
  end
end
