# frozen_string_literal: true

require "test_helper"

class BlobsControllerTest < ActiveSupport::TestCase
  test "BlobsController should exist" do
    assert M365ActiveStorage::BlobsController
  end

  test "BlobsController should have show action" do
    assert M365ActiveStorage::BlobsController.instance_methods.include?(:show)
  end
end
