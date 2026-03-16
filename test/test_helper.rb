# frozen_string_literal: true

require "simplecov"

SimpleCov.start do
  add_filter "test/"
end

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "minitest/autorun"
require "mocha/minitest"
require "rails"
require "m365_active_storage"

$current_class = nil # rubocop:disable Style/GlobalVars
module ActiveSupport
  class TestCase
    def setup
      if self.class.name != $current_class # rubocop:disable Style/GlobalVars
        print "\n" if $current_class # rubocop:disable Style/GlobalVars
        print "\n\e[4;37;1m#{self.class.name.underscore.humanize}\e[0m"
        $current_class = self.class.name # rubocop:disable Style/GlobalVars
        if [AuthenticationTest, HttpTest, SharepointServiceTest].include?(self.class) && !credentials_defined?
          print "\n\e[33mskipping tests due to missing credentials\e[0m"
        end
      end

      skip("skipping...") if [AuthenticationTest, HttpTest, SharepointServiceTest].include?(self.class) && !credentials_defined?
    end

    def teardown
      test_name = self.name.gsub("test_", "").humanize
      print "\n"

      if failures.empty? && !error?
        # Test passed
        print "\e[32mpass\e[0m #{test_name}"
      elsif skipped?
        # Test was skipped
        print "\e[33mskip\e[0m #{test_name}"
      elsif failures.any?
        # Test failed with assertion failure
        color = error? ? "30;41" : "31;1"
        message = error? ? "error" : "fail"
        print "\n\e[#{color}m#{message}\e[0m #{test_name}"
        color = error? ? "30;1" : "31"
        failures.each do |failure|
          print ["\e[#{color}m", failure.location, failure.message, "\e[0m\n"].join("\n")
        end
      elsif error?
        # Test had an error/exception
        print "\e[30;41merror\e[0m #{test_name}"
        print "\n\e[31m#{error.class}: #{error.message}\e[0m"

        print "\n\e[31m#{error.backtrace.first(5).join("\n")}\e[0m" if error.backtrace
      end
    end

    def load_storage_config
      storage_config = {}
      yaml_config = YAML.safe_load(File.read(File.expand_path("../test/fixtures/storage.yml", __dir__)))["sharepoint"]
      yaml_config.each { |key, value| storage_config[key.to_sym] = value }
      storage_config
    end

    def load_test_storage_config
      {
        ms_graph_url: ENV["MS_GRAPH_URL"],
        ms_graph_version: ENV["MS_GRAPH_VERSION"],
        auth_host: ENV["AUTH_HOST"],
        tenant_id: ENV["OAUTH_TENANT"],
        app_id: ENV["OAUTH_APP_ID"],
        secret: ENV["OAUTH_SECRET"],
        site_id: ENV["SHAREPOINT_SITE_ID"],
        drive_id: ENV["SHAREPOINT_DRIVE_ID"],
      }
    end

    def credentials_defined?
      load_test_storage_config.values.all?(&:present?)
    end
  end
end
