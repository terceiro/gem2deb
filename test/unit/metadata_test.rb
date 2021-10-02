require_relative '../test_helper'
require 'gem2deb/metadata'
require 'yaml'

$GIT_ABUSER_GEMSPEC_1 = <<EOF
Gem::Specification.new do |s|
  s.name        = "gitabuser1"
  s.version     = "1"
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Antonio Terceiro"]
  s.email       = ["terceiro@debian.org"]
  s.homepage    = ""
  s.summary     = %q{Sample gem that }
  s.description = %q{This gem is used to test the case where dh-make-ruby is called on a directory}

  s.files             = `/unexisting/git ls-files`.split
  s.executables       = `/unexisting/git ls-files`.split.select { |f| File.executable?(f) }
  s.test_files        = `/unexisting/git ls-files`.split.select { |f| f =~ /^(test|spec|features)/ }
  s.require_paths     = ["lib"]
end
EOF

$GIT_ABUSER_GEMSPEC_2 = <<'EOF'
Gem::Specification.new do |s|
  s.name        = "gitabuser2"
  s.version     = "1"
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Antonio Terceiro"]
  s.email       = ["terceiro@debian.org"]
  s.homepage    = ""
  s.summary     = %q{Sample gem that }
  s.description = %q{This gem is used to test the case where dh-make-ruby is called on a directory}

  s.files             = `/unexisting/git ls-files`.split("\n")
  s.executables       = `/unexisting/git ls-files`.split("\n").select { |f| File.executable?(f) }
  s.test_files        = `/unexisting/git ls-files`.split("\n").select { |f| f =~ /^(test|spec|features)/ }
  s.require_paths     = ["lib"]
end
EOF

$GIT_ABUSER_GEMSPEC_3 = <<'EOF'
Gem::Specification.new do |s|
  s.name        = "gitabuser3"
  s.version     = "1"
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Antonio Terceiro"]
  s.email       = ["terceiro@debian.org"]
  s.homepage    = ""
  s.summary     = %q{Sample gem that }
  s.description = %q{This gem is used to test the case where dh-make-ruby is called on a directory}

  s.files             = `/unexisting/git ls-files`.split($/)
  s.executables       = `/unexisting/git ls-files`.split($/).select { |f| File.executable?(f) }
  s.test_files        = `/unexisting/git ls-files`.split($/).select { |f| f =~ /^(test|spec|features)/ }
  s.require_paths     = ["lib"]
end
EOF

$GIT_ABUSER_GEMSPEC_4 = <<'EOF'
Gem::Specification.new do |s|
  s.name        = "gitabuser4"
  s.version     = "1"
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Antonio Terceiro"]
  s.email       = ["terceiro@debian.org"]
  s.homepage    = ""
  s.summary     = %q{Sample gem that }
  s.description = %q{This gem is used to test the case where dh-make-ruby is called on a directory}

  s.files             = `/unexisting/git ls-files`.split($/).
    select { |f| File.basename(f) != '.foobar' }
  s.executables       = `/unexisting/git ls-files`.split($/).select { |f| File.executable?(f) }
  s.test_files        = `/unexisting/git ls-files`.split($/).select { |f| f =~ /^(test|spec|features)/ }
  s.require_paths     = ["lib"]
end
EOF

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
    FileUtils.rm_rf('test/tmp')
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
    should 'use bin/ as bindir' do
      assert_equal 'bin', @metadata.bindir
    end
    should 'use all programs under bin/' do
      Dir.stubs(:glob).with('test/tmp/bin/*').returns(['test/tmp/bin/foo'])
      assert_equal ['foo'], @metadata.executables
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

    should 'use whatever directory gemspec says as bindir' do
      @gemspec.stubs(:bindir).returns('programs')
      assert_equal 'programs', @metadata.bindir
    end

    should 'resist bindir being false' do
      @gemspec.stubs(:bindir).returns(false)
      assert_equal 'bin', @metadata.bindir
    end

    should 'use whatever programs the gemspec says' do
      @gemspec.stubs(:executables).returns(%w(foo bar))
      assert_equal ['foo', 'bar'], @metadata.executables
    end

    should 'not use an empty executables list' do
      @gemspec.stubs(:executables).returns([])
      assert_equal nil, @metadata.executables
    end

  end

  context 'with debian/gemspec' do
    setup do
      @gemspec = Gem::Specification.new do |spec|
        spec.name = 'mypkg'
        spec.version = '1.2.3'
      end
      FileUtils.mkdir_p('test/tmp/debian')
      File.open('test/tmp/debian/gemspec', 'w') { |f| f.write(@gemspec.to_ruby) }
    end
    should 'use it' do
      metadata = Gem2Deb::Metadata.new('test/tmp')
      assert_equal 'mypkg-1.2.3', [metadata.gemspec.name, metadata.gemspec.version].join('-')
    end
    should 'resolve symlinks' do
      FileUtils.mv('test/tmp/debian/gemspec', 'test/tmp/mypkg.gemspec')
      FileUtils.cp('test/tmp/mypkg.gemspec', 'test/tmp/other.gemspec')
      Dir.chdir('test/tmp/debian') { FileUtils.ln_s('../mypkg.gemspec', 'gemspec') }
      path = File.expand_path('test/tmp/mypkg.gemspec')
      Gem::Specification.expects(:load).with(path).returns(@gemspec)
      metadata = Gem2Deb::Metadata.new('test/tmp')
      assert_equal 'mypkg', metadata.gemspec.name
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

  context 'timestamps' do
    should 'use date from changelog if available' do
      Dir.chdir('test/sample/install_as_gem') do
        @metadata = Gem2Deb::Metadata.new('.')
      end
      # the gemspec only stores the date and zeroes the hour
      assert_equal Time.parse('2015-11-20 00:00:00 UTC'), @metadata.gemspec.date
    end
  end

  context 'filelists' do
    should 'should always be sorted' do
      @metadata = Gem2Deb::Metadata.new('test/sample/unsorted_names')
      correctly_sorted = ['lib/file1.rb', 'lib/file2.rb']
      assert_equal correctly_sorted, @metadata.gemspec.test_files.select { |f| f.include? 'lib/file' }
      assert_equal correctly_sorted, @metadata.gemspec.files.select { |f| f.include? 'lib/file' }
    end
  end

  context 'when upstream abuses git in gemspecs' do
    [
      $GIT_ABUSER_GEMSPEC_1,
      $GIT_ABUSER_GEMSPEC_2,
      $GIT_ABUSER_GEMSPEC_3,
      $GIT_ABUSER_GEMSPEC_4,
    ].each_with_index do |gemspec,i|
      n = i + 1
      should "workaround git usage (#{n})" do
        # create
        dir = File.join(tmpdir, "gitabuser#{n}")
        FileUtils.mkdir_p(dir)
        Dir.chdir dir do
          File.open("gitabuser#{n}.gemspec", 'w') do |f|
            f.puts(gemspec)
          end
          FileUtils.mkdir 'lib'
          File.open("lib/gitabuser#{n}.rb", 'w') do |f|
            f.puts "module GitAbuser#{n}; end"
          end
        end


        @metadata = self.class.silently { Gem2Deb::Metadata.new(dir) }
        assert_not_nil @metadata.gemspec
        assert_equal ["gitabuser#{n}.gemspec", "lib/gitabuser#{i+1}.rb"], @metadata.gemspec.files
      end
    end

  end

  context 'calculating Debian dependencies' do
    setup do
      @metadata = Gem2Deb::Metadata.new(SIMPLE_GEM_SOURCE)
      @dependencies = @metadata.get_debian_dependencies(false)
    end
    should 'get simple dependency' do
      assert_include @dependencies, 'ruby-dep'
    end
    should 'not use dependencies with exact versions' do
      assert_include @dependencies, 'ruby-depwithversion (>= 1.0)'
    end
    should 'get version with spermy' do
      assert_include @dependencies, 'ruby-depwithspermy (>= 1.0)'
    end
    should 'get version with >' do
      assert_include @dependencies, 'ruby-depwithgt (>> 1.0)'
    end
    should 'get version with two requirements' do
      assert_include @dependencies, 'ruby-depwith2versions (>= 1.0)'
      assert_include @dependencies, 'ruby-depwith2versions (<< 2.0)'
    end
    should 'treat rails versions as a special case' do
      assert_include @dependencies, 'ruby-railties (>= 2:6.0)'
      assert_include @dependencies, 'ruby-railties (<< 2:7.0)'
    end
  end

end
