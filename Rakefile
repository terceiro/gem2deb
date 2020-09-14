require 'rake/testtask'

ENV['LANG'] = 'C'

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

Rake::TestTask.new('test:coverage') do |t|
  t.libs << "test"
  t.test_files = FileList['test/unit/*_test.rb']
  t.ruby_opts = ['-rsimplecov']
  t.verbose = true
end

Rake::TestTask.new('test:integration') do |t|
  t.libs << 'test'
  t.test_files = FileList['test/integration/*_test.rb']
  t.verbose = true
end

desc "Run tests in debug mode (e.g. don't delete temporary files)"
task 'test:debug' do
  ENV['DEBUG'] = 'yes'
  Rake::Task['test'].invoke
end

desc "Builds the Debian package and installs it on your system"
task :install do
  sh 'dpkg-buildpackage -us -uc'
  sh "sudo debi"
end

desc "Builds a git snapshot package"
task 'snapshot:build', :install do |task,args|
  if !system('git diff-index --quiet HEAD')
    fail "Can't build package; you have uncommitted changes"
  end

  date = `date --iso=seconds |sed 's/+.*//' |sed 's/[-T:]//g'`.chomp
  branch = `git symbolic-ref --short HEAD`.strip
  newbranch = 'snapshot-' + date

  sh 'git checkout -b ' + newbranch
  sh "sed -i '1 s/)/~git#{date})/' debian/changelog"
  sh 'git commit -a -m snapshot-' + date
  begin
    sh 'DEB_BUILD_OPTIONS=nocheck gbp buildpackage --git-ignore-branch -us -uc'
    if args[:install]
      sh 'sudo debi'
    end
  ensure
    sh 'git checkout ' + branch
  end
end

desc "Installs a git snapshot package"
task 'snapshot:install' do
  Rake::Task['snapshot:build'].invoke(true)
end


desc "Checks for inconsistencies between version numbers in the code and in debian/changelog"
task :version_check do
  $code_version = `ruby -Ilib -rgem2deb/version -e 'puts Gem2Deb::VERSION'`.strip
  $debian_version = `dpkg-parsechangelog | grep '^Version: ' | cut -d ' ' -f 2`.strip
  if $code_version != $debian_version
    msg ="W: Inconsistent version numbers: lib/gem2deb/version.rb says #{$code_version}, debian/changelog says #{$debian_version}"
    if STDIN.isatty && STDOUT.isatty && STDERR.isatty
      # highlight the message in red
      puts("\033[31;40m%s\033[m" % msg)
    else
      puts msg
    end
    fail if ENV.has_key?('VERSION_CHECK_FATAL')
  end
end

namespace :release do
  desc "Releases to Debian (very much tied to terceiro's workflow)"
  task :debian do
    ENV['VERSION_CHECK_FATAL'] = 'yes'
    Rake::Task['version_check'].invoke

    sh 'gbp buildpackage --git-builder=sbuild'
    sh 'gbp buildpackage --git-tag-only'
    sh 'debsign'
    sh 'git push --all'
    sh 'git push --tags'
    sh 'debrelease'
  end
end
