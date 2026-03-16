# frozen_string_literal: true

module M365ActiveStorage
  # == HTTP Request Handler
  #
  # Manages authenticated HTTPS requests to the Microsoft Graph API.
  #
  # === Responsibilities
  #
  # * Construct authenticated HTTP requests with OAuth2 tokens
  # * Support all HTTP methods (GET, POST, PUT, DELETE, HEAD)
  # * Automatically include authorization headers
  # * Handle redirect responses
  # * Manage SSL/TLS connections
  #
  # === Architecture
  #
  # The Http class wraps the standard library Net::HTTP with authentication.
  # It automatically:
  # 1. Ensures a valid OAuth2 token is available
  # 2. Creates the appropriate HTTP request object
  # 3. Adds the Authorization header with the Bearer token
  # 4. Adds any custom headers (Content-Type, etc.)
  # 5. Executes the request over HTTPS
  #
  # === Example Usage
  #
  #   config = M365ActiveStorage::Configuration.new(**config_params)
  #   auth = M365ActiveStorage::Authentication.new(config)
  #   http = M365ActiveStorage::Http.new(auth)
  #
  #   # GET request
  #   response = http.get("https://graph.microsoft.com/v1.0/sites/site-id")
  #   
  #   # PUT request with body
  #   response = http.put(upload_url, file_content, {"Content-Type" => "application/octet-stream"})
  #
  # @attr_reader [Authentication] auth The authentication handler for obtaining tokens
  #
  # @see M365ActiveStorage::Authentication
  # @see M365ActiveStorage::Configuration
  class Http
    attr_reader :auth

    # Initialize the HTTP handler
    #
    # @param [Authentication] auth The authentication handler
    def initialize(auth)
      @auth = auth
      @config = auth.config
    end

    # Perform a HEAD request
    #
    # Sends an HTTPS HEAD request to the specified URL.
    # HEAD requests are useful for checking resource existence or metadata without downloading the full body.
    #
    # @param [String] check_url The URL to request
    # @return [Net::HTTPResponse] The HTTP response object
    #
    # @example
    #   response = http.head("https://graph.microsoft.com/v1.0/sites/site-id")
    #   puts response.code  # => "200"
    #
    # @see #perform_and_request
    def head(check_url)
      perform_and_request(Net::HTTP::Head, check_url)
    end

    # Perform a DELETE request
    #
    # Sends an HTTPS DELETE request to delete a resource at the specified URL.
    #
    # @param [String] delete_url The URL of the resource to delete
    # @return [Net::HTTPResponse] The HTTP response object
    #
    # @example
    #   response = http.delete("https://graph.microsoft.com/v1.0/drives/drive-id/items/file-id")
    #   puts response.code  # => "204"
    #
    # @see #perform_and_request
    def delete(delete_url)
      perform_and_request(Net::HTTP::Delete, delete_url)
    end

    # Perform a GET request
    #
    # Sends an HTTPS GET request to retrieve a resource.
    #
    # @param [String] url The URL to request
    # @param [Hash, nil] options Optional headers to add to the request
    # @return [Net::HTTPResponse] The HTTP response object
    #
    # @example
    #   response = http.get("https://graph.microsoft.com/v1.0/sites/site-id")
    #   response = http.get(url, {"Accept" => "application/json"})
    #
    # @see #perform_and_request
    def get(url, options = nil)
      perform_and_request(Net::HTTP::Get, url, options)
    end

    # Perform a request following a redirect URL without authorization
    #
    # Sends a GET request to a redirect URL (typically from Microsoft or Azure storage).
    # Explicitly removes the Authorization header to allow following CDN or Azure Blob Storage redirects
    # that would be invalid with a Bearer token.
    #
    # @param [String] url The redirect URL to follow
    # @return [Net::HTTPResponse] The response from the redirect target
    #
    # @example
    #   # In follow_redirect after receiving a 302 response
    #   response = http.redirect_to(download_url)
    #
    # @see ActiveStorage::Service::SharepointService#handle_download_response
    def redirect_to(url)
      http, request = perform(Net::HTTP::Get, url)
      # do not set authorization header to redirect url from Microsoft, it could redirect to a CDN or Azure blob storage
      request.delete("Authorization")
      http.request(request)
    end

    # Perform a PUT request
    #
    # Sends an HTTPS PUT request to upload or update a resource.
    #
    # @param [String] url The URL of the resource
    # @param [String] body The request body (file content, etc.)
    # @param [Hash, nil] options Optional headers to add to the request (should include Content-Type)
    # @return [Net::HTTPResponse] The HTTP response object
    #
    # @example
    #   file_content = File.read("document.pdf")
    #   response = http.put(
    #     "https://graph.microsoft.com/v1.0/drives/drive-id/root:/file.pdf:/content",
    #     file_content,
    #     {"Content-Type" => "application/octet-stream"}
    #   )
    #
    # @see #perform
    def put(url, body, options = nil)
      http, request = perform(Net::HTTP::Put, url, options)
      request.body = body
      http.request(request)
    end

    # Perform a POST request
    #
    # Sends an HTTPS POST request to create or update a resource.
    #
    # @param [String] url The URL of the resource
    # @param [String] body The request body (JSON, form data, etc.)
    # @param [Hash, nil] options Optional headers to add to the request
    # @return [Net::HTTPResponse] The HTTP response object
    #
    # @example
    #   json_body = {name: "document.pdf"}.to_json
    #   response = http.post(
    #     "https://graph.microsoft.com/v1.0/drives/drive-id/items",
    #     json_body,
    #     {"Content-Type" => "application/json"}
    #   )
    #
    # @see #perform
    def post(url, body, options = nil)
      http, request = perform(Net::HTTP::Post, url, options)
      request.body = body
      http.request(request)
    end

    private

    # Build and prepare an HTTP request with authentication
    #
    # Sets up the Net::HTTP connection and request object with:
    # * HTTPS/SSL configuration
    # * Bearer token authorization header
    # * Any additional headers passed via options
    #
    # @param [Class] method_class The Net::HTTP request class (Get, Post, Put, Delete, Head)
    # @param [String] url The request URL
    # @param [Hash, nil] options Optional additional headers
    # @return [Array<Net::HTTP, Net::HTTPRequest>] Array of [http_connection, request_object]
    #
    # @example
    #   http, request = perform(Net::HTTP::Get, "https://api.example.com/data")
    #   response = http.request(request)
    def perform(method_class, url, options = nil)
      uri = URI(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      request = method_class.new(uri.request_uri)
      request["Authorization"] = "Bearer #{@auth.token}"
      options&.each { |key, value| request[key] = value }
      [http, request]
    end

    # Build request and execute it in one step
    #
    # Convenience method that combines #perform and the actual HTTP request execution.
    # Used for simple requests without a request body.
    #
    # @param [Class] method_class The Net::HTTP request class
    # @param [String] url The request URL
    # @param [Hash, nil] options Optional headers
    # @return [Net::HTTPResponse] The HTTP response object
    #
    # @see #perform
    def perform_and_request(method_class, url, options = nil)
      http, request = perform(method_class, url, options)
      http.request(request)
    end
  end
end
