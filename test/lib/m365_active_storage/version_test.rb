# frozen_string_literal: true

require "test_helper"

class VersionTest < ActiveSupport::TestCase
  test "should have a version number" do
    assert ::M365ActiveStorage::VERSION
  end
end
