require_relative '../test_helper'
require 'gem2deb/test_runner'

class TestRunnerTest < Gem2DebTestCase

  def self.should_detect_test_runner(dir)
    should "detect a test runner for #{dir}" do
      Dir.chdir(dir) do
        assert Gem2Deb::TestRunner.detect
      end
    end
  end

  def self.test_should_return(exitstatus, dir, autopkgtest: false)
    should_detect_test_runner(dir)
    should "exit #{exitstatus} when testing #{dir}" do
      begin
        Dir.chdir(dir) do
          self.class.silence_stream(STDOUT) do
            self.class.silence_stream(STDERR) do
              runner = Gem2Deb::TestRunner.detect
              runner.autopkgtest = autopkgtest
              def runner.exec(*cmd)
                system(*cmd)
                exit($?.exitstatus)
              end
              rubylib = ENV['RUBYLIB']
              ENV['RUBYLIB'] = GEM2DEB_ROOT_SOURCE_DIR + '/lib'
              begin
                runner.run_tests
              ensure
                ENV['RUBYLIB'] = rubylib
              end
            end
          end
        end
      rescue SystemExit => e
        assert_equal exitstatus, e.status
      end
    end
  end

  test_should_return 0, 'test/sample/test_runner/yaml/pass'
  test_should_return 1, 'test/sample/test_runner/yaml/fail'
  test_should_return 0, 'test/sample/test_runner/rake/pass'
  test_should_return 1, 'test/sample/test_runner/rake/fail'
  test_should_return 0, 'test/sample/test_runner/rb/pass'
  test_should_return 1, 'test/sample/test_runner/rb/fail'

  test_should_return 77, 'test/sample/test_runner/no_tests', autopkgtest: true
  test_should_return 0, 'test/sample/ruby-autopkgtest-example', autopkgtest: true

end
