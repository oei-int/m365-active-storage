require "active_storage/service"
require "active_storage/configuration"
require "active_storage/authentication"
require "active_storage/http"
require "net/http"
require "uri"
require "json"
require "cgi"

module ActiveStorage
  # == SharePoint Storage Service
  #
  # Implements the Active Storage service interface to interact with Microsoft 365 SharePoint
  # via the Microsoft Graph API.
  #
  # === Overview
  #
  # This service allows Rails Active Storage to use Microsoft 365 SharePoint as a file storage backend.
  # It handles all file operations (upload, download, delete, check existence) by communicating
  # with SharePoint via the Microsoft Graph API.
  #
  # === Configuration
  #
  # Configure in your storage.yml:
  #
  #   # config/storage.yml
  #   sharepoint:
  #     service: Sharepoint
  #     ms_graph_url: https://graph.microsoft.com
  #     ms_graph_version: v1.0
  #     auth_host: https://login.microsoftonline.com
  #     tenant_id: your-tenant-id
  #     app_id: your-app-id
  #     secret: your-client-secret
  #     site_id: your-site-id
  #     drive_id: your-drive-id
  #
  # Then activate in your environment config:
  #
  #   config.active_storage.service = :sharepoint
  #
  # === Usage
  #
  # Use normally with Active Storage in your models:
  #
  #   class Document < ApplicationRecord
  #     has_one_attached :file
  #   end
  #
  #   doc = Document.new
  #   doc.file.attach(io: File.open("document.pdf"), filename: "doc.pdf")
  #   doc.file.download        # => file contents
  #   doc.file.attached?       # => true
  #
  # === Implementation Details
  #
  # The service implements all required Active Storage methods:
  # * +upload(key, io)+ - Upload file to SharePoint
  # * +download(key)+ - Download file from SharePoint
  # * +download_chunk(key, range)+ - Download partial file content
  # * +delete(key)+ - Delete file from SharePoint
  # * +exist?(key)+ - Check if file exists
  # * +url(key)+ - Get URL for blob
  #
  # === Key Points
  #
  # * File keys are mapped to blob filenames for better SharePoint organization
  # * Automatic token refresh on 401 responses
  # * Redirect following for CDN/Azure Blob Storage downloads
  # * Signed URLs prevent 401 issues by routing through authenticated controller
  # * Deferred deletion using PendingDelete registry
  #
  # === Error Handling
  #
  # The service raises StandardError for invalid operations. Common errors:
  # * "Failed to upload file to SharePoint" - Upload returned non-success status
  # * "Failed to download file from SharePoint" - Download failed with error status
  # * "Filename not found for key" - Blob deleted before file deletion from SharePoint
  #
  # === Performance Considerations
  #
  # * Tokens are cached and automatically refreshed before expiration
  # * Chunked downloads supported for large files
  # * Redirects followed to access CDN URLs without authorization issues
  #
  # @attr_reader [Configuration] config SharePoint configuration
  # @attr_reader [Authentication] auth Authentication handler
  # @attr_reader [Http] http HTTP request handler
  #
  # @see M365ActiveStorage::Configuration
  # @see M365ActiveStorage::Authentication
  # @see M365ActiveStorage::Http
  # @see M365ActiveStorage::PendingDelete
  # @see ActiveStorage::Service
  class Service::SharepointService < Service
    attr_reader :config, :auth, :http

    # Initialize the SharePoint storage service
    #
    # Creates configuration, authentication, and HTTP handler instances.
    # The service is ready to use immediately after initialization.
    #
    # @param [Hash] options Configuration options (passed to Configuration)
    # @option options [String] :ms_graph_url The Microsoft Graph API URL
    # @option options [String] :ms_graph_version The Graph API version
    # @option options [String] :auth_host The OAuth2 host
    # @option options [String] :tenant_id Azure AD tenant ID
    # @option options [String] :app_id Azure AD application ID
    # @option options [String] :secret Azure AD client secret
    # @option options [String] :site_id SharePoint site ID
    # @option options [String] :drive_id SharePoint drive ID
    #
    # @raise [KeyError] if required configuration is missing
    #
    # @example
    #   service = ActiveStorage::Service::SharepointService.new(
    #     ms_graph_url: "https://graph.microsoft.com",
    #     # ... other required params
    #   )
    #
    # @see M365ActiveStorage::Configuration
    def initialize(**options) # rubocop:disable Lint/MissingSuper
      @config = M365ActiveStorage::Configuration.new(**options)
      @auth = M365ActiveStorage::Authentication.new(@config)
      @http = M365ActiveStorage::Http.new(@auth)
    end

    # Upload a file to SharePoint
    #
    # Uploads file content to the configured SharePoint drive.
    # The file is stored with the blob's filename for better organization in SharePoint.
    #
    # @param [String] key The Active Storage blob key (ignored, filename used instead)
    # @param [IO] io The file content as an IO object
    # @return [void]
    #
    # @raise [StandardError] if upload fails
    #
    # @example
    #   file = File.open("document.pdf")
    #   service.upload("key123", file)  # File now in SharePoint
    #
    # @see #get_storage_name
    # @see #handle_upload_response
    def upload(key, io, **)
      auth.ensure_valid_token
      storage_name = get_storage_name(key)
      upload_url = "#{drive_url}/root:/#{CGI.escape(storage_name)}:/content"
      response = http.put(upload_url, io.read, { "Content-Type": "application/octet-stream" })
      handle_upload_response(response)
    end

    # Download a file from SharePoint
    #
    # Retrieves the complete file content from SharePoint.
    # Automatically retries once if the token expires (401 response).
    #
    # @param [String] key The blob key to download
    # @return [String] The file content
    #
    # @raise [StandardError] if download fails
    #
    # @example
    #   content = service.download("key123")  # => file contents
    #
    # @see #fetch_download
    # @see #handle_download_response
    def download(key)
      response = fetch_download(key)
      if response.code.to_i == 401
        # Token might have expired, force refresh and retry once
        auth.expire_token!
        response = fetch_download(key)
      end
      handle_download_response(response)
    end

    # Fetch the raw download response from SharePoint
    #
    # Internal method that makes the actual HTTP request for downloading a file.
    #
    # @param [String] key The blob key to download
    # @return [Net::HTTPResponse] The HTTP response
    #
    # @see #download
    def fetch_download(key)
      auth.ensure_valid_token
      storage_name = get_storage_name(key)
      download_url = "#{drive_url}/root:/#{CGI.escape(storage_name)}:/content"
      http.get(download_url)
    end

    # Handle the HTTP response from a download request
    #
    # Processes the response, following redirects if necessary (e.g., to CDN or Azure Blob Storage).
    # Successful responses return the file content.
    #
    # @param [Net::HTTPResponse] response The HTTP response from SharePoint
    # @return [String] The file content
    #
    # @raise [StandardError] if response code indicates an error
    #
    # @example
    #   response = http.get(url)
    #   content = handle_download_response(response)  # => file contents
    #
    # @see #follow_redirect
    def handle_download_response(response)
      case response.code.to_i
      when 200, 206
        response.body
      when 302, 301
        follow_redirect(response["location"])
      else
        raise "Failed to download file from SharePoint: #{response.code}"
      end
    end

    # Download a chunk (partial content) of a file from SharePoint
    #
    # Retrieves a specific byte range from a file, useful for large file streaming.
    # Implements HTTP Range requests.
    #
    # @param [String] key The blob key to download from
    # @param [Range] range The byte range to retrieve (e.g., 0..1023)
    # @return [String] The requested file chunk
    #
    # @raise [StandardError] if download fails
    #
    # @example
    #   # Download first 1MB of a file
    #   chunk = service.download_chunk("key123", 0..(1024*1024-1))
    #
    # @see #fetch_chunk
    # @see #handle_download_response
    def download_chunk(key, range)
      auth.ensure_valid_token
      response = fetch_chunk(key, range)
      handle_download_response(response)
    end

    # Fetch chunk response from SharePoint using HTTP Range header
    #
    # Internal method for making the HTTP Range request.
    #
    # @param [String] key The blob key
    # @param [Range] range The byte range to retrieve
    # @return [Net::HTTPResponse] The HTTP response
    #
    # @see #download_chunk
    def fetch_chunk(key, range)
      storage_name = get_storage_name(key)
      download_url = "#{drive_url}/root:/#{CGI.escape(storage_name)}:/content"
      http.get(download_url, { "Range": "bytes=#{range.begin}-#{range.end}" })
    end

    # Delete a file from SharePoint
    #
    # Removes a file from the SharePoint drive. Requires the filename to be available
    # from the PendingDelete registry (set before the blob was deleted).
    #
    # @param [String] key The blob key to delete
    # @return [Boolean] true if deletion was successful (204 response)
    #
    # @raise [StandardError] if filename not found or deletion fails
    #
    # @example
    #   success = service.delete("key123")  # => true
    #
    # @see M365ActiveStorage::PendingDelete
    # @see M365ActiveStorage::Railtie
    def delete(key)
      auth.ensure_valid_token

      storage_name = @config.storage_key.downcase == "key" ? key : M365ActiveStorage::PendingDelete.get(key)
      raise "Filename not found for key #{key}. Cannot delete file from SharePoint." unless storage_name

      delete_url = "#{drive_url}/root:/#{CGI.escape(storage_name)}"
      response = http.delete(delete_url)
      response.code.to_i == 204
    end

    # Delete files matching a prefix (compatibility method)
    #
    # Retro compatibility method. Not implemented as the service works with
    # individual keys rather than prefixes. Raises no error to maintain compatibility.
    #
    # @param [String] prefix The prefix to match (unused)
    # @return [void]
    def delete_prefixed(prefix); end

    # Check if a file exists in SharePoint
    #
    # Queries SharePoint to check if a file with the given key exists.
    #
    # @param [String] key The blob key to check
    # @return [Boolean] true if the file exists, false otherwise
    #
    # @example
    #   service.exist?("key123")  # => true or false
    def exist?(key)
      auth.ensure_valid_token
      storage_name = get_storage_name(key)
      check_url = "#{drive_url}/root:/#{CGI.escape(storage_name)}"
      response = http.get(check_url)
      response.code.to_i == 200
    end

    # Get the URL for downloading a blob
    #
    # Returns a signed URL through the authenticated BlobsController rather than
    # a direct SharePoint URL. This is necessary because direct SharePoint URLs
    # require the Authorization header and would fail in browsers.
    #
    # The URL includes the blob's signed ID for security and the filename for reference.
    #
    # @param [String] key The blob key to get the URL for
    # @return [String] A path to the authenticated blob download action
    #
    # @example
    #   url = service.url("key123")
    #   # => "/rails/active_storage/blobs/signed_id/document.pdf"
    #
    # @see M365ActiveStorage::BlobsController
    # @see ActiveStorage::Blob#signed_id
    def url(key, **)
      # returns the path to the authenticated blob controller as direct sharepoint urls will fail with 401
      # since its required the Authorization header to access the file
      # Find the blob and return the signed blob URL
      blob = ActiveStorage::Blob.find_by(key: key)

      # return a path to the authenticated blob controller
      "/rails/active_storage/blobs/#{blob.signed_id}/#{CGI.escape(blob.filename.to_s)}"
    end

    private

    # Get the SharePoint drive API endpoint URL
    #
    # Constructs the Microsoft Graph API URL for the configured drive.
    #
    # @return [String] The complete drive API URL
    #
    # @example
    #   # => "https://graph.microsoft.com/v1.0/sites/site-id/drives/drive-id"
    def drive_url
      "#{config.ms_graph_endpoint}/sites/#{config.site_id}/drives/#{config.drive_id}"
    end

    # Handle the response from an upload request
    #
    # Validates that the upload succeeded (201 Created or 200 OK).
    # Raises an error for any other status code.
    #
    # @param [Net::HTTPResponse] response The HTTP response from the upload
    # @return [void]
    #
    # @raise [StandardError] if upload failed
    def handle_upload_response(response)
      return if [201, 200].include?(response.code.to_i)

      raise "Failed to upload file to SharePoint"
    end

    # Get the storage name for a blob key
    #
    # Tries to use the blob's filename if available, otherwise falls back to the key.
    # This ensures files are organized by their actual names in SharePoint rather
    # than random keys.
    #
    # @param [String] key The blob key
    # @return [String] The filename to use for storage
    #
    # @example
    #   # If blob exists: => "document.pdf"
    #   # If blob doesn't exist: => "abc123def456"
    def get_storage_name(key)
      return key if @config.storage_key.downcase == "key"

      blob = ActiveStorage::Blob.find_by(key: key)
      return key unless blob.present? && blob.filename.present?

      blob.filename.to_s
    end

    # Follow HTTP redirects up to 5 times
    #
    # Handles redirect responses by following the redirect URL.
    # Prevents infinite redirect loops by limiting to 5 hops.
    #
    # This is used for CDN or Azure Blob Storage redirects that don't require
    # the authorization header.
    #
    # @param [String] redirect_url The URL to redirect to
    # @param [Integer] times The number of redirects followed so far
    # @return [String] The final response body
    #
    # @raise [StandardError] if final redirect fails or max hops exceeded
    #
    # @see M365ActiveStorage::Http#redirect_to
    def follow_redirect(redirect_url, times = 0)
      # Prevent infinite redirects
      return nil if times > 5

      response = http.redirect_to(redirect_url)
      return response.body if response.code.to_i == 200

      unless [301, 302].include?(response.code.to_i) && response["location"]
        follow_redirect(response["location"], times + 1)
        return
      end

      raise "failed to download file from redirect: #{response.code}"
    end
  end
end
