require 'test/unit'
require 'shoulda-context'
require 'mocha'
require 'fileutils'
require 'tmpdir'
require 'tempfile'

Gem2DebTestCase = Test::Unit::TestCase
class Gem2DebTestCase

  VENDOR_ARCH_DIRS = {
    'ruby1.8'   => `ruby1.8   -rrbconfig -e "puts RbConfig::CONFIG['vendorarchdir']"`.strip,
    'ruby1.9.1' => `ruby1.9.1 -rrbconfig -e "puts RbConfig::CONFIG['vendorarchdir']"`.strip,
  }

  require 'test_helper/samples'
  include Gem2DebTestCase::Samples

  GEM2DEB_ROOT_SOURCE_DIR = File.expand_path(File.join(File.dirname(__FILE__), '..'))

  FileUtils.mkdir_p(TMP_DIR)

  class << self
    def tmpdir
      @tmpdir ||= File.join(Gem2DebTestCase::TMP_DIR, name)
      FileUtils.mkdir_p(@tmpdir)
      @tmpdir
    end
    def one_time_setup_blocks
      @one_time_setup_blocks ||= []
    end
    def one_time_setup(&block)
      one_time_setup_blocks << block
    end
    def one_time_setup?
      @one_time_setup
    end
    def one_time_setup!
      unless one_time_setup?
        one_time_setup_blocks.each(&:call)
        @one_time_setup = true
      end
      setup_cleanup
    end
    def setup_cleanup
      unless $__gem2deb_tests_cleanup_installed
        at_exit do
          if ENV['GEM2DEB_DEBUG']
            puts
            puts "======================================================================="
            puts "Temporary test files left in #{Gem2DebTestCase::TMP_DIR} for inspection!"
            puts
          else
            FileUtils.rm_rf(Gem2DebTestCase::TMP_DIR)
          end
        end
      end
      $__gem2deb_tests_cleanup_installed = true
    end
  end
  def tmpdir
    self.class.tmpdir
  end

  def setup
    self.class.one_time_setup!
  end

  protected

  def unpack(tarball)
    Dir.chdir(File.dirname(tarball)) do
      system 'tar', 'xzf', File.basename(tarball)
      ret = yield
      contents(tarball).each do |f|
        FileUtils.rm_rf(f)
      end
      ret
    end
  end

  def contents(tarball)
    IO.popen("tar tzf #{tarball}").readlines.map(&:strip)
  end

  def assert_contained_in_tarball(tarball, file)
    list = contents(tarball)
    assert list.include?(file), "#{tarball} should contain #{file} (contents: #{list.inspect})"
  end

  def assert_not_contained_in_tarball(tarball, file)
    list = contents(tarball)
    assert !list.include?(file), "#{tarball} should NOT contain #{file} (contents: #{list.inspect})"
  end

  def assert_file_exists(path)
    assert File.exist?(path), "#{path} should exist"
  end

  def assert_no_file_exists(path)
    assert !File.exist?(path), "#{path} should NOT exist"
  end

  # Installation-related functions

  def installed_file_path(gem_dirname, package, path)
    File.join(self.class.tmpdir, 'ruby-' + gem_dirname, 'debian', package, path)
  end

  def assert_installed(gem_dirname, package, path)
    assert_file_exists installed_file_path(gem_dirname, package, path)
  end

  def self.silence_stream(stream)
    orig_stream = stream.clone
    begin
      Tempfile.open('gem2deb-tests-stdoud') do |f|
        stream.reopen(f)
        yield
      end
    ensure
      stream.reopen(orig_stream)
    end
  end

  # Runs a command with the current (in-development) gem2deb environment
  # loaded. PATH, PERL5LIB and RUBYLIB environment variables are tweaked to
  # make sure that everything that comes from gem2deb has precedence over
  # system-wide installed versions.
  def self.run_command(cmd)
    # setup Perl lib for debhelper7
    perl5lib = File.join(tmpdir, 'perl5')
    debhelper_buildsystems = File.join(perl5lib, 'Debian/Debhelper/Buildsystem')
    FileUtils.mkdir_p debhelper_buildsystems
    FileUtils.cp "#{GEM2DEB_ROOT_SOURCE_DIR}/debhelper7/buildsystem/ruby.pm", debhelper_buildsystems
    debhelper_sequences = File.join(perl5lib, 'Debian/Debhelper/Sequence')
    FileUtils.mkdir_p debhelper_sequences
    FileUtils.cp "#{GEM2DEB_ROOT_SOURCE_DIR}/debhelper7/sequence/ruby.pm", debhelper_sequences

    # setup the environment
    ENV['PERL5LIB'] = perl5lib
    ENV['PATH'] = [File.join(GEM2DEB_ROOT_SOURCE_DIR, 'bin'), ENV['PATH']].join(':')
    ENV['RUBYLIB'] = File.join(GEM2DEB_ROOT_SOURCE_DIR, 'lib')

    @run_command_id ||= -1
    @run_command_id += 1

    # run the command
    stdout = File.join(tmpdir, 'stdout.' + self.name + '.' + @run_command_id.to_s)
    stderr = File.join(tmpdir, 'stderr.' + self.name + '.' + @run_command_id.to_s)
    error = nil
    system("#{cmd} >#{stdout} 2>#{stderr}")
    if $?.exitstatus != 0
      error = "Command [#{cmd}] failed!\n"
      error << "Standard output:\n" << File.read(stdout).lines.map { |line| "  #{line}"}.join
      error << "Standard error:\n" << File.read(stderr).lines.map { |line| "  #{line}"}.join
    end
    FileUtils.rm_f(stdout)
    FileUtils.rm_f(stderr)
    if error
      raise error
    end
  end

  # See above
  def run_command(cmd)
    self.class.run_command(cmd)
  end

end
