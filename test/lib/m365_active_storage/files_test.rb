# frozen_string_literal: true

require "test_helper"

class FilesTest < ActiveSupport::TestCase
  test "should return all the controller files" do
    assert M365ActiveStorage::Files.controller_files.any?
    controllers = M365ActiveStorage::Files.controller_files.map { |file| file.split("/").last }
    assert controllers.include?("blobs_controller.rb"), "Expected controller files to include 'blobs_controller.rb', but got #{controllers.inspect}"
  end

  test "should return all the controller classes" do
    assert M365ActiveStorage::Files.controller_classes.any?
    controller_class_names = M365ActiveStorage::Files.controller_classes.map(&:name)
    assert controller_class_names.include?(M365ActiveStorage::BlobsController.name), "Expected controller classes to include 'M365ActiveStorage::BlobsController', but got #{controller_class_names.inspect}"
  end
end
