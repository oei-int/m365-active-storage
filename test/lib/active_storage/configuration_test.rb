# frozen_string_literal: true

require "test_helper"

class ConfigurationTest < ActiveSupport::TestCase
  include M365ActiveStorage

  test "should raise error if missing required keys" do
    storage_config = load_storage_config
    %i[auth_host tenant_id app_id secret ms_graph_url ms_graph_version site_id drive_id storage_key].each do |key|
      storage_config.delete(key)
      assert_raises(KeyError, "expected raise a KeyError exception for missing #{key}") { Configuration.new(**storage_config) }
      storage_config = load_storage_config
    end
  end

  test "should read attributes from storage.yml" do
    puts "---> Testing Configuration initialization with storage.yml values"
    puts load_storage_config.inspect
    config = Configuration.new(**load_storage_config)
    assert_equal "https://login.microsoftonline.com", config.auth_host
    assert_equal "test-tenant-id", config.tenant_id
    assert_equal "test-app-id", config.app_id
    assert_equal "test-secret", config.secret
    assert_equal "https://graph.microsoft.com", config.ms_graph_url
    assert_equal "v1.0", config.ms_graph_version
    assert_equal "test-site-id", config.site_id
    assert_equal "test-drive-id", config.drive_id
    assert_equal "test-storage-key", config.storage_key
  end

  test "should have attributes as readonly" do
    config = Configuration.new(**load_storage_config)
    assert_raises(NoMethodError) { config.auth_host = "new-value" }
    assert_raises(NoMethodError) { config.tenant_id = "new-value" }
  end

  test "should raise error if storage param exists in the storage.yml but is empty" do
    storage_config = load_storage_config
    %i[auth_host tenant_id app_id secret ms_graph_url ms_graph_version site_id drive_id storage_key].each do |key|
      storage_config[key] = ""
      assert_raises(KeyError, "expected raise a KeyError exception for empty #{key}") { Configuration.new(**storage_config) }
      storage_config = load_storage_config
    end
  end
end
