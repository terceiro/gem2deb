require 'rake/testtask'

Rake::TestTask.new(:default) do |t|
  t.test_files = 'test/simpleextension_with_name_clash_test.rb'
end
