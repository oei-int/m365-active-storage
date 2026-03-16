# frozen_string_literal: true

require "test_helper"

class M365ActiveStorageTest < ActiveSupport::TestCase
  test "Module should exist" do
    assert M365ActiveStorage
  end

  test "BlobsController should exist" do
    assert M365ActiveStorage::BlobsController
  end

  test "Configuration should exist" do
    assert M365ActiveStorage::Configuration
  end
end
