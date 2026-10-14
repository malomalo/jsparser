# require 'bundler/setup'
# require "bundler/gem_tasks"
# Bundler.require(:development)

require 'fileutils'
require "rake/testtask"
require "rubygems/package_task"

# Test Task
Rake::TestTask.new do |t|
    t.libs << 'lib' << 'test'
    t.test_files = FileList[ARGV[1] ? ARGV[1] : 'test/**/*_test.rb']
    t.warning = true
    t.verbose = true
end

desc "Parse and print every .js file in DIR and compare the result with acorn (rake oracle DIR=path)"
task :oracle, [:dir] do |_, args|
  $LOAD_PATH.unshift File.expand_path('lib', __dir__)
  require_relative 'test/oracle/oracle'
  JSParser::Oracle.run(args[:dir] || ENV['DIR'])
end

spec = Gem::Specification.load("jsparser.gemspec")

Gem::PackageTask.new(spec) do |pkg|
#   pkg.need_zip = true
#   pkg.need_tar = true
end
