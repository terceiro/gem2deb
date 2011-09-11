require 'rake/testtask'

task :default => :test

task :test => :version_check do
  puts '=> Unit tests'
  Rake::Task['test:unit'].invoke
  puts '=> Integration tests'
  Rake::Task['test:integration'].invoke
end

Rake::TestTask.new('test:unit') do |t|
  t.libs << "test"
  t.test_files = FileList['test/unit/*_test.rb']
  t.verbose = true
end

Rake::TestTask.new('test:integration') do |t|
  t.libs << 'test'
  t.test_files = FileList['test/integration/*_test.rb']
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

desc "Builds a git snapshot package"
task :snapshot do
  sh 'cp debian/changelog debian/changelog.git'
  date = `date --iso=seconds |sed 's/+.*//' |sed 's/[-T:]//g'`.chomp
  sh "sed -i '1 s/)/~git#{date})/' debian/changelog"
  sh 'ls debian/changelog.git'
  sh 'dpkg-buildpackage -us -uc'
  sh 'ls debian/changelog.git'
  sh 'mv debian/changelog.git debian/changelog'
end

desc "Checks for inconsistencies between version numbers in the code and in debian/changelog"
task :version_check do
  code_version = `ruby -Ilib -rgem2deb/version -e 'puts Gem2Deb::VERSION'`.strip
  debian_version = `dpkg-parsechangelog | grep '^Version: ' | cut -d ' ' -f 2`.strip
  if code_version != debian_version
    msg ="W: Inconsistent version numbers: lib/gem2deb.rb says #{code_version}, debian/changelog says #{debian_version}"
    if STDIN.isatty && STDOUT.isatty && STDERR.isatty
      # highlight the message in red
      puts("\033[31;40m%s\033[m" % msg)
    else
      puts msg
    end
  end
end
