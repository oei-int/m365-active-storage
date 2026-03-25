# frozen_string_literal: true

require "test_helper"
require "ostruct"

module ActiveStorage
  class Blob
    def self.find_by(key); end
  end
end

class SharepointServiceTest < ActiveSupport::TestCase
  include M365ActiveStorage

  TEST_FILENAME = "test/fixtures/icon.png"

  def create_sharepoint_service
    ActiveStorage::Service::SharepointService.new(**load_test_storage_config)
  end

  def file_key_and_service
    file = File.open(TEST_FILENAME, "rb")
    key = "test_upload__icon.png"
    service = create_sharepoint_service

    [file, key, service]
  end

  test "should create an instance of SharepointService" do
    service = create_sharepoint_service
    assert_instance_of ActiveStorage::Service::SharepointService, service
    assert service.config
    assert service.auth
    assert service.http
  end
  test "service should use configuration" do
    service = create_sharepoint_service
    config = Configuration.new(**load_test_storage_config)

    assert_equal config.auth_host, service.config.auth_host
    assert_equal config.tenant_id, service.config.tenant_id
    assert_equal config.app_id, service.config.app_id
    assert_equal config.secret, service.config.secret
    assert_equal config.ms_graph_url, service.config.ms_graph_url
    assert_equal config.ms_graph_version, service.config.ms_graph_version
    assert_equal config.ms_graph_endpoint, service.config.ms_graph_endpoint
    assert_equal config.site_id, service.config.site_id
    assert_equal config.drive_id, service.config.drive_id
  end

  test "should get url for key" do
    file, key, service = file_key_and_service
    ActiveStorage::Blob.stubs(:find_by).with(key: key)
                       .returns(OpenStruct.new(signed_id: "signed-#{key}-id", filename: "#{key}.filename"))
    url = service.url(key)
    assert_equal "/rails/active_storage/blobs/signed-#{key}-id/#{CGI.escape("#{key}.filename")}", url
  end

  test "should get encoded url for key" do
    file, key, service = file_key_and_service
    key_with_spaces = key.gsub("_", " ")
    ActiveStorage::Blob.stubs(:find_by).with(key: key_with_spaces)
                       .returns(OpenStruct.new(signed_id: "signed-#{key_with_spaces}-id", filename: "#{key_with_spaces}.filename"))
    url = service.url(key_with_spaces)
    assert_equal "/rails/active_storage/blobs/signed-#{key_with_spaces}-id/#{CGI.escape("#{key_with_spaces}.filename")}", url
  end

  test "should verify file doesn't exist" do
    _, key, service = file_key_and_service
    M365ActiveStorage::PendingDelete.store(key, key)
    service.delete(key) if service.exist?(key)
    assert_not service.exist?(key)
  end

  test "should upload a file" do
    file, key, service = file_key_and_service
    service.upload(key, file)
    assert service.exist?(key)
  end

  test "should download a file and verify content" do
    file, key, service = file_key_and_service
    original_digest = Digest::MD5.file(TEST_FILENAME).hexdigest
    service.upload(key, file)
    downloaded_data = service.download(key)
    assert_equal original_digest, Digest::MD5.hexdigest(downloaded_data)
  end

  test "should not refresh token if not expired" do
    file, key, service = file_key_and_service
    service.upload(key, file)
    service.download(key)
    token = service.auth.token
    service.download(key)
    assert_equal token, service.auth.token
  end

  test "should refresh token if expired" do
    file, key, service = file_key_and_service
    service.upload(key, file)
    service.download(key)
    token = service.auth.token

    Time.stubs(:current).returns(service.auth.token_expires_at + 1.minute)
    service.download(key)
    assert_not_equal token, service.auth.token
  end

  test "should download a chunk of the file and verify content" do
    file, key, service = file_key_and_service
    range = (0..file.size)
    original_digest = Digest::MD5.file(TEST_FILENAME).hexdigest
    service.upload(key, file)
    downloaded_data = service.download_chunk(key, range)
    assert_equal original_digest, Digest::MD5.hexdigest(downloaded_data)
  end

  test "should delete a file" do
    file, key, service = file_key_and_service
    service.upload(key, file)
    assert service.exist?(key)

    M365ActiveStorage::PendingDelete.store(key, key)
    service.delete(key)
    assert_not service.exist?(key)
  end

  test "should request token if not authorized" do
    file, key, service = file_key_and_service
    service.upload(key, file)
    Net::HTTPResponse.any_instance.stubs(:code).returns("401")
    assert_raises(RuntimeError, "Failed to download file from SharePoint: 401") do
      assert service.download(key)
    end
  end

  test "should persist sharepoint id in blob metadata after successful upload" do
    _, key, service = file_key_and_service
    response = OpenStruct.new(code: "201", body: { "id" => "sharepoint-item-123" }.to_json)

    blob = mock
    blob.stubs(:metadata).returns({ "existing" => "data", "sharepoint" => { "name" => "doc" } })
    blob.expects(:update_columns).with(metadata: {
      "existing" => "data",
      "sharepoint" => { "name" => "doc", "id" => "sharepoint-item-123" },
      "sharepoint_id" => "sharepoint-item-123"
    })

    ActiveStorage::Blob.stubs(:find_by).with(key: key).returns(blob)
    service.send(:handle_upload_response, key, response)
  end
end
