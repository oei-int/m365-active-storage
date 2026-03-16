# frozen_string_literal: true

require "test_helper"
class HttpTest < ActiveSupport::TestCase
  include M365ActiveStorage

  def create_http_object
    config = Configuration.new(**load_test_storage_config)
    @auth = Authentication.new(config)
    Http.new(@auth)
  end

  test "should initialize Http with auth" do
    http = create_http_object
    assert http
  end

  test "perform method should not be exposed" do
    assert_not Http.instance_methods.include?(:perform), "Expected :perform to be a private method"
  end

  test "perform_and_request method should not be exposed" do
    assert_not Http.instance_methods.include?(:perform_and_request), "Expected :perform_and_request to be a private method"
  end

  test "head method should return an http error on invalid url" do
    http = create_http_object
    assert_instance_of Net::HTTPNotFound, http.head("https://example.com/test")
  end

  test "delete method should return an http error on invalid url" do
    http = create_http_object
    assert_instance_of Net::HTTPMethodNotAllowed, http.delete("https://example.com/test")
  end

  test "get method should return an http error on invalid url" do
    http = create_http_object
    assert_instance_of Net::HTTPNotFound, http.get("https://example.com/test")
  end

  test "redirect method should return an http error on invalid url" do
    http = create_http_object
    assert_instance_of Net::HTTPNotFound, http.redirect_to("https://example.com/test")
  end

  test "put method should return an http error on invalid url" do
    http = create_http_object
    assert_instance_of Net::HTTPMethodNotAllowed, http.put("https://example.com/test", "test body")
  end

  # test "should initialize Http with auth" do
  #   config = Configuration.new(**load_test_storage_config)
  #   @auth = Authentication.new(@config)
  #   @http = Http.new(@config, @auth)
  # end
end