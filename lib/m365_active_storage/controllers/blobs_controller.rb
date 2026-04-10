# frozen_string_literal: true

module M365ActiveStorage
  # == SharePoint Blob Download Controller
  #
  # Handles serving of attached files stored in SharePoint through a Rails action.
  #
  # === Responsibilities
  #
  # * Serve blobs securely using signed URLs
  # * Validate blob access through ActiveStorage signatures
  # * Handle Download requests with appropriate content headers
  # * Recover from authentication errors (e.g., expired tokens)
  # * Provide appropriate HTTP error responses
  #
  # === Route
  #
  # This controller is automatically registered with Rails via the Railtie.
  # Typically used with ActiveStorage's url_for helper:
  #
  #   url_for(@document.file)  # => /rails/active_storage/blobs/signed_id/document.pdf
  #
  # === Security
  #
  # Access is secured through ActiveStorage signed IDs. The signature ensures:
  # * Only authorized users can download blobs
  # * URLs are time-limited if configured
  # * Tampering with signed IDs is detected
  #
  # === Example Usage
  #
  # In your Rails view:
  #
  #   <%= link_to "Download", @document.file, download: true %>
  #   <%= image_tag @document.image %>
  #
  # === Error Handling
  #
  # * Invalid signatures return 404 Not Found
  # * Authentication failures trigger token refresh and retry
  # * Other errors return 500 Internal Server Error
  #
  # @see ActiveStorage::Blob
  # @see ActiveStorage::Service::SharepointService
  class BlobsController < ActionController::Base
    protect_from_forgery with: :exception

    # Display/download a blob
    #
    # Retrieves a blob by its signed ID and sends it to the client with appropriate
    # Content-Type and disposition headers.
    #
    # This action:
    # 1. Extracts the signed blob ID from the URL
    # 2. Validates the signature using ActiveStorage's signing mechanism
    # 3. Downloads the file from SharePoint
    # 4. Returns it with appropriate HTTP headers
    # 5. Handles token expiration by retrying once
    #
    # @return [void] Sends file content to client or error response
    #
    # @example
    #   # GET /rails/active_storage/blobs/:signed_id/document.pdf
    #   # Returns the document with:
    #   # Content-Type: application/pdf
    #   # Content-Disposition: inline; filename="document.pdf"
    #
    # @raise [ActiveSupport::MessageVerifier::InvalidSignature] if signature is invalid
    # @raise [StandardError] if download fails after retry
    #
    # @see #find_blob
    # @see #download
    def show
      # Skip sharepoint authentication - blob is secured via signed ID
      signed_id = params[:signed_id]
      blob = find_blob(signed_id)
      return head :not_found unless blob

      download(blob)
    rescue StandardError
      head :internal_server_error
    end

    private

    # Find a blob by its signed ID
    #
    # Uses ActiveStorage's signature verification to find a blob.
    # This ensures only authorized users can access specific blobs.
    #
    # @param [String] signed_id The signed blob ID from the URL
    # @return [ActiveStorage::Blob, nil] The blob if signature is valid, nil otherwise
    #
    # @example
    #   blob = find_blob(params[:signed_id])
    #   if blob
    #     puts "Blob found: #{blob.filename}"
    #   else
    #     puts "Invalid signature or blob not found"
    #   end
    #
    # @see ActiveStorage::Blob.find_signed!
    def find_blob(signed_id)
      ActiveStorage::Blob.find_signed!(signed_id)
    rescue ActiveSupport::MessageVerifier::InvalidSignature
      nil
    end

    # Download and serve a blob to the client
    #
    # Retrieves the file from SharePoint and sends it to the client with
    # appropriate content type and disposition headers.
    #
    # If the SharePoint token is expired (401 response), automatically
    # retries once after refreshing the token.
    #
    # @param [ActiveStorage::Blob] blob The blob to download
    # @return [void] Sends file content to client
    #
    # @raise [StandardError] if download fails after retry
    #
    # @see #send_data
    # @see ActiveStorage::Blob#download
    def download(blob)
      file_data = blob.download
      send_data file_data,
                type: blob.content_type,
                disposition: params[:disposition] || 'inline',
                filename: blob.filename.to_s
    rescue StandardError
      raise
    end
  end
end
