require "bundler/gem_tasks"

#require 'rubygems'
require 'rake'
require 'rake/testtask'

#tests as gem
task :test do
  exec '/bin/bash', './test/test_with_railsapp'
end

namespace :test do
  Rake::TestTask.new(:unit) do |t|
    t.libs << 'lib'
    t.libs << 'test'
    t.test_files = FileList['test/unit/**/*_test.rb']
    t.verbose = true
  end
end

task default: :test

begin
  gem 'rdoc'
  require 'rdoc/task'

  Rake::RDocTask.new do |rdoc|
    version = HealthCheck::VERSION

    rdoc.rdoc_dir = 'rdoc'
    rdoc.title = "health_check #{version}"
    rdoc.rdoc_files.include('README*')
    rdoc.rdoc_files.include('CHANGELOG')
    rdoc.rdoc_files.include('MIT-LICENSE')
    rdoc.rdoc_files.include('lib/**/*.rb')
  end
rescue Gem::LoadError
  puts "rdoc (or a dependency) not available. Install it with: gem install rdoc"
end
