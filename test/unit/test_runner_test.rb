require_relative '../test_helper'
require 'gem2deb/test_runner'

class TestRunnerTest < Gem2DebTestCase

  def self.should_pass_tests(dir)
    should_succeed(dir, true)
  end

  def self.should_fail_tests(dir)
    should_succeed(dir, false)
  end

  def self.should_detect_test_runner(dir)
    should "detect a test runner for #{dir}" do
      Dir.chdir(dir) do
        assert Gem2Deb::TestRunner.detect
      end
    end
  end

  def self.should_succeed(dir, true_or_false)
    should_detect_test_runner(dir)
    should "pass tests on #{dir}" do
      begin
        Dir.chdir(dir) do
          self.class.silence_stream(STDOUT) do
            self.class.silence_stream(STDERR) do
              runner = Gem2Deb::TestRunner.detect
              def runner.exec(*cmd)
                system(*cmd)
                exit($?.exitstatus)
              end
              rubylib = ENV['RUBYLIB']
              ENV['RUBYLIB'] = GEM2DEB_ROOT_SOURCE_DIR + '/lib'
              runner.run_tests
              ENV['RUBYLIB'] = rubylib
            end
          end
        end
      rescue SystemExit => e
        assert_equal true_or_false, e.success?
      end
    end
  end

  should_pass_tests 'test/sample/test_runner/yaml/pass'
  should_fail_tests 'test/sample/test_runner/yaml/fail'
  should_pass_tests 'test/sample/test_runner/rake/pass'
  should_fail_tests 'test/sample/test_runner/rake/fail'
  should_pass_tests 'test/sample/test_runner/rb/pass'
  should_fail_tests 'test/sample/test_runner/rb/fail'
  should_detect_test_runner 'test/sample/test_runner/no_tests'

end
