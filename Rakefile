require 'rake/testtask'

task :default => :test

Rake::TestTask.new do |t|
  t.libs << "lib"
  t.libs << "test"
  t.test_files = FileList['test/*_test.rb']
  t.verbose = true
end

desc "Run tests in debug mode (e.g. don't delete temporary files)"
task 'test:debug' do
  ENV['GEM2DEB_TEST_DEBUG'] = 'yes'
  Rake::Task['test'].invoke
end

desc "Builds the Debian package and installs it on your system"
task :install do
  sh 'dpkg-buildpackage -us -uc'
  sh "sudo debi"
end
