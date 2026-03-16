# frozen_string_literal: true

require_relative "lib/m365_active_storage/version"

Gem::Specification.new do |spec|
  spec.name = "m365_active_storage"
  spec.version = M365ActiveStorage::VERSION
  spec.authors = ["Óscar León"]
  spec.email = ["oscar.leon@oei.int"]

  spec.summary = "Gem to use Microsoft 365 as a storage service for Rails Active Storage."
  spec.description = "Integration gem for Rails Active Storage to use Microsoft 365 (SharePoint) as a storage backend. " \
                     "Provides seamless OAuth2 authentication and Microsoft Graph API integration for file management."
  spec.homepage = "https://github.com/oei-int/m365-active-storage"
  spec.license = "GPL-3.0"
  spec.required_ruby_version = ">= 3.2.0"

  # Metadata
  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/CHANGELOG.md"
  spec.metadata["documentation_uri"] = "https://rubydoc.info/gems/m365_active_storage"
  spec.metadata["bug_tracker_uri"] = "#{spec.homepage}/issues"

  # RDoc documentation settings
  spec.rdoc_options = [
    "--title", "M365 Active Storage - SharePoint Storage for Rails",
    "--main", "README.md",
    "--exclude", "test",
    "--markup", "markdown",
    "--line-numbers"
  ]
  spec.extra_rdoc_files = [
    "README.md",
    "CHANGELOG.md",
    "LICENSE.txt"
  ]

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore test/ .rubocop.yml])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem
  # spec.add_dependency "example-gem", "~> 1.0"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
