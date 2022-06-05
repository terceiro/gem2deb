require_relative '../test_helper'
require 'gem2deb/source'

class SourceTest < Gem2DebTestCase

  def debian_control
    @debian_control ||= []
  end

  def t_tmpdir
    @t_tmpdir ||= File.join(tmpdir, method_name).tap do |dir|
      FileUtils.mkdir_p(File.join(dir, "debian"))
    end
  end

  def source
    @source ||= Dir.chdir(t_tmpdir) do
      File.write("debian/control", debian_control.join("\n"))
      Gem2Deb::Source.new
    end
  end

  context "selecting package layout" do

    should 'default to single-binary' do
      debian_control << 'Package: ruby-foo'
      debian_control << 'Package: ruby-bar'
      ruby_foo = { :binary_package => 'ruby-foo', :root => '.' }
      assert_equal [ruby_foo], source.send(:packages)
    end

    should 'ignore packages without X-DhRuby-Root when one of them has it' do
      debian_control << 'Package: ruby-foo'
      debian_control << 'Package: ruby-bar'
      debian_control << 'X-DhRuby-Root: bar'

      ruby_bar = { :binary_package => 'ruby-bar', :root => 'bar' }
      assert_equal [ruby_bar], source.send(:packages)
    end

    should 'detect multibinary' do
      debian_control << 'Package: ruby-foo'
      debian_control << 'X-DhRuby-Root: foo'
      debian_control << 'Package: ruby-bar'
      debian_control << 'X-DhRuby-Root: bar'
      ruby_foo = { :binary_package => 'ruby-foo', :root => 'foo' }
      ruby_bar = { :binary_package => 'ruby-bar', :root => 'bar' }
      assert_equal [ruby_foo, ruby_bar], source.send(:packages)
    end

  end

  context "determining debhelper compat level" do
    should 'detect from DH_COMPAT' do
      ENV.expects(:[]).with("DH_COMPAT").returns("14").at_least_once
      assert_equal 14, source.debhelper_compat
    end

    should 'detect from debian/compat' do
      File.write(File.join(t_tmpdir, "debian", "compat"), "12\n")
      assert_equal 12, source.debhelper_compat
    end

    should 'detect from Build-Depends' do
      debian_control << 'Source: ruby-foobar'
      debian_control << 'Build-Depends: gem2deb, debhelper-compat (= 11), ruby-baz'
      assert_equal 11, source.debhelper_compat
    end

    should 'detect from Build-Depends with multiple lines' do
      debian_control << 'Source: ruby-foobar'
      debian_control << "Build-Depends: gem2deb,\n debhelper-compat (= 11),\n ruby-baz"
      assert_equal 11, source.debhelper_compat
    end

    should 'always be a number' do
      assert_kind_of Integer, source.debhelper_compat
    end
  end

end

