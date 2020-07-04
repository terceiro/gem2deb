require_relative '../test_helper'
require 'gem2deb/installer'

class InstallerTest < Gem2DebTestCase

  MULTIBINARY = 'test/sample/multibinary'
  FOO = File.join(MULTIBINARY, 'foo')
  BAR = File.join(MULTIBINARY, 'foo')

  context 'constructor' do

    setup do
      @foo_installer = Gem2Deb::Installer.new('ruby-foo', FOO)
    end

    should 'store binary package name' do
      assert_equal 'ruby-foo', @foo_installer.binary_package
    end

    should 'expand and store root directory' do
      assert_match %r{.+#{FOO}$}, @foo_installer.root
    end

    should 'read metadata' do
      assert @foo_installer.metadata.is_a?(Gem2Deb::Metadata)
    end

  end

  context 'finding duplicate files' do
    setup do
      @installer = Gem2Deb::Installer.new('ruby-foo', FOO)
      @installer.verbose = false
      @tmpdir = Dir.mktmpdir
    end
    teardown do
      FileUtils.rm_rf(@tmpdir)
    end
    should 'remove duplicates' do
      Dir.chdir(@tmpdir) do
        FileUtils.mkdir('dir1')
        FileUtils.mkdir('dir2')
        ['dir1','dir2'].each do |d|
          File.open(File.join(d, 'test.rb'), 'w') { |f| f.puts "# Nice File"}
        end
        @installer.send(:remove_duplicate_files, 'dir1', 'dir2')
        assert !File.exist?('dir2')
      end
    end
    should 'not crash with duplicates in subdirectories' do
      Dir.chdir(@tmpdir) do
        FileUtils.mkdir_p('dir1/subdir')
        FileUtils.touch('dir1/subdir/test.rb')
        FileUtils.mkdir_p('dir2/subdir')
        FileUtils.touch('dir2/subdir/test.rb')
        @installer.send(:remove_duplicate_files, 'dir1', 'dir2')
        assert !File.exist?('dir2')
      end
    end
  end

  context 'installing Ruby files' do
    should 'not crash when directories to be installed have names in the exclusion list' do
      installer = Gem2Deb::Installer.new('ruby-foo', FOO)
      Dir.chdir('test/sample/install_files/') do
        installer.send(:install_files, 'lib', File.join(tmpdir, 'install_files_destdir'), 644)
      end
    end
  end

  context 'rewriting shebangs' do
    setup do
      @installer = Gem2Deb::Installer.new('ruby-foo', FOO)
      @installer.verbose = false

      FileUtils.cp_r('test/sample/rewrite_shebangs', self.class.tmpdir)
      @installer.stubs(:destdir).with(:bindir).returns(self.class.tmpdir + '/rewrite_shebangs')

      # The fact that this call does not crash means we won't crash when
      # /usr/bin has subdirectories
      @installer.send(:rewrite_shebangs, '/usr/bin/ruby')
    end
    teardown do
      FileUtils.rm_f(self.class.tmpdir + '/rewrite_shebangs')
    end

    should 'rewrite shebangs of programs directly under bin/' do
      assert_match %r{^#!/usr/bin/ruby}, File.read(self.class.tmpdir + '/rewrite_shebangs/usr/bin/prog')
    end
    should 'rewrite shebangs with whitespace around/' do
      assert_match %r{^#!/usr/bin/ruby}, File.read(self.class.tmpdir + '/rewrite_shebangs/usr/bin/with-spaces')
    end
    should 'rewrite shebangs in subdirs of bin/' do
      assert_match %r{^#!/usr/bin/ruby}, File.read(self.class.tmpdir + '/rewrite_shebangs/usr/bin/subdir/prog')
    end
    should 'not rewrite shebangs non-Ruby scripts' do
      lines = File.readlines(self.class.tmpdir + '/rewrite_shebangs/usr/bin/shell-script')
      assert_match %r{#!/bin/sh}, lines[0]
    end
    should 'leave programs with correct permissions after rewriting shebangs' do
      assert_equal '100755', '%o' % File.stat(self.class.tmpdir + '/rewrite_shebangs/usr/bin/no-shebang').mode
    end
    should 'rewrite shebang to use `/usr/bin/ruby` if all versions are supported' do
      @installer.stubs(:all_ruby_versions_supported?).returns(true)
      @installer.expects(:rewrite_shebangs).with('/usr/bin/ruby')
      @installer.send(:update_shebangs)
    end
    should "rewrite shebang to usr #{OLDER_RUBY_VERSION_BINARY} if only #{OLDER_RUBY_VERSION} is supported" do
      @installer.stubs(:ruby_versions).returns([OLDER_RUBY_VERSION])
      @installer.stubs(:supported_ruby_versions).returns([OLDER_RUBY_VERSION, 'rubyX.Y'])
      @installer.expects(:rewrite_shebangs).with(OLDER_RUBY_VERSION_BINARY)
      @installer.send(:update_shebangs)
    end
  end

  context "Ruby versions supported" do
    setup do
      @installer = Gem2Deb::Installer.new('ruby-foo', FOO)
    end
    should 'know when all versions are supported' do
      # ruby_versions contains all supported versions by default
      assert_equal true, @installer.send(:all_ruby_versions_supported?)
    end
    should 'know when not all versions are supported' do
      @installer.stubs(:ruby_versions).returns([OLDER_RUBY_VERSION])
      @installer.stubs(:supported_ruby_versions).returns([OLDER_RUBY_VERSION, 'rubyX.Y'])
      assert_equal false, @installer.send(:all_ruby_versions_supported?)
    end
  end

end

