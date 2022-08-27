require_relative '../test_helper'
require 'gem2deb'

class Gem2DebTest < Gem2DebTestCase
  class TestGem2Deb
    include Gem2Deb
  end

  def gem2deb
    @gem2deb ||= TestGem2Deb.new
  end

  def test_host_build
    assert_equal gem2deb.host_arch.class, String
  end

  def test_build_build
    assert_equal gem2deb.build_arch.class, String
  end

  def test_cross_building
    gem2deb.instance_variable_set(:@host_arch, "one")
    gem2deb.instance_variable_set(:@build_arch, "another")
    assert gem2deb.cross_building?
  end

  def test_default_compiler
    gem2deb.instance_variable_set(:@host_arch, "aarch64-linux-gnu")
    gem2deb.instance_variable_set(:@host_arch_gnu, "aarch64-linux-gnu")
    gem2deb.instance_variable_set(:@build_arch, "x86_64-linux-gnu")
    assert_equal "aarch64-linux-gnu-gcc", gem2deb.default_compiler("gcc")
  end
end
