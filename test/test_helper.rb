require 'test/unit'
require 'shoulda'
require 'mocha'
require 'fileutils'
require 'tmpdir'
require 'tempfile'

class Gem2DebTestCase < Test::Unit::TestCase

  require 'test/helper/samples'
  include Gem2DebTestCase::Samples

  GEM2DEB_ROOT_SOURCE_DIR = File.expand_path(File.join(File.dirname(__FILE__), '..'))

  FileUtils.mkdir_p(TMP_DIR)

  class << self
    def tmpdir
      @tmpdir ||= File.join(Gem2DebTestCase::TMP_DIR, name)
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
        FileUtils.mkdir_p(tmpdir)
        one_time_setup_blocks.each(&:call)
        @one_time_setup = true
      end
    end
    attr_accessor :instance
  end
  def tmpdir
    self.class.tmpdir
  end
  def instance
    self.class.instance
  end
  def tmpdir
    self.class.tmpdir
  end

  def setup
    self.class.one_time_setup!
  end

  def run(runner)
    return if @method_name.to_s == 'default_test'
    super
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

  def self.silence_all_output
    silence_stream(STDOUT) do
      silence_stream(STDERR) do
        yield
      end
    end
  end

end

class Test::Unit::AutoRunner
  alias :orig_run :run
  def run
    ret = nil
    if ENV['GEM2DEB_TEST_DEBUG']
      puts "Running tests in debug mode ..."
      ret = orig_run
      puts
      puts "======================================================================="
      puts "Temporary test files left in #{Gem2DebTestCase::TMP_DIR} for inspection!"
      puts
    else
      ret = orig_run
      FileUtils.rm_rf(Gem2DebTestCase::TMP_DIR)
    end
    ret
  end
end
