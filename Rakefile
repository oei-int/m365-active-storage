# frozen_string_literal: true

require "bundler/gem_tasks"
require "minitest/test_task"
require "rdoc/task"

Minitest::TestTask.create do |t|
  t.framework = %(require "test/test_helper.rb")
  t.test_globs = ["test/**/*_test.rb"]
end

require "rubocop/rake_task"

RuboCop::RakeTask.new

# RDoc task for generating API documentation
RDoc::Task.new do |rdoc|
  rdoc.title = "M365 Active Storage - SharePoint Storage for Rails"
  rdoc.main = "README.md"
  rdoc.rdoc_files.include("README.md", "CHANGELOG.md", "LICENSE.txt", "lib/**/*.rb")
  rdoc.rdoc_files.exclude("test/**/*", "spec/**/*")
  rdoc.options = [
    "--markup=markdown",
    "--line-numbers",
    "--all",
    "--hyperlink-all"
  ]
  rdoc.rdoc_dir = "doc"
end

task default: %i[test rubocop]

