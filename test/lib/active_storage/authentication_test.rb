# frozen_string_literal: true

require "test_helper"

class AuthenticationTest < ActiveSupport::TestCase
  include M365ActiveStorage
  test "Initialize with configuration" do
    config = Configuration.new(**load_test_storage_config)

    auth = Authentication.new(config)
    assert auth
    assert_equal config, auth.config
    assert_nil auth.token
    assert_nil auth.token_expires_at
  end

  test "should fetch access token" do
    config = Configuration.new(**load_test_storage_config)
    auth = Authentication.new(config)

    auth.ensure_valid_token
    assert auth.token
    assert_instance_of String, auth.token
    assert auth.token_expires_at > Time.now
  end

  test "should fetch the same token if not expired" do
    config = Configuration.new(**load_test_storage_config)
    auth = Authentication.new(config)

    auth.ensure_valid_token
    token = auth.token
    assert token

    auth.ensure_valid_token
    new_token = auth.token
    assert_equal token, new_token, "Expected to return the same token if not expired"
  end

  test "should fetch a new token if expired" do
    config = Configuration.new(**load_test_storage_config)
    auth = Authentication.new(config)

    auth.ensure_valid_token
    token = auth.token
    assert token

    # Simulate token expiration by setting expires_at in the past
    # auth.instance_variable_set(:@token_expires_at, Time.now - 1)
    Time.stubs(:current).returns(auth.token_expires_at + 1.minute)

    auth.ensure_valid_token
    new_token = auth.token
    assert new_token
    assert_not_equal token, new_token, "Expected to fetch a new token if expired"
  end

  test "should expire token" do
    config = Configuration.new(**load_test_storage_config)
    auth = Authentication.new(config)

    auth.ensure_valid_token
    token = auth.token
    assert token

    auth.expire_token!
    assert auth.token_expires_at < Time.now, "Expected token to be expired"
  end
end
