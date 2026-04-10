# frozen_string_literal: true

require "test_helper"

class BlobsControllerTest < ActiveSupport::TestCase
  test "BlobsController should exist" do
    assert M365ActiveStorage::BlobsController
  end

  test "BlobsController should have show action" do
    assert M365ActiveStorage::BlobsController.instance_methods.include?(:show)
  end

  test "BlobsController enables forgery protection" do
    callbacks = M365ActiveStorage::BlobsController._process_action_callbacks
    verify_callback = callbacks.find { |callback| callback.filter == :verify_authenticity_token }

    assert verify_callback, "Expected BlobsController to verify authenticity tokens"
  end
end
