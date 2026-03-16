# frozen_string_literal: true

module M365ActiveStorage
  # == OAuth2 Authentication Handler
  #
  # Manages OAuth2 authentication with Microsoft Azure AD to obtain and maintain
  # access tokens for Microsoft Graph API calls.
  #
  # === Responsibilities
  #
  # * Obtain OAuth2 access tokens using client credentials flow
  # * Cache tokens and automatically refresh when expired
  # * Handle authentication errors and retries
  # * Manage token lifecycle and expiration
  #
  # === Architecture
  #
  # The Authentication class implements the OAuth2 Client Credentials flow:
  # 1. Exchanges client ID and secret for an access token
  # 2. Caches the token with its expiration time
  # 3. Automatically refreshes tokens before expiration
  # 4. Provides token to HTTP requests for API calls
  #
  # === Example Usage
  #
  #   config = M365ActiveStorage::Configuration.new(**config_params)
  #   auth = M365ActiveStorage::Authentication.new(config)
  #   
  #   # Ensure we have a valid token before making API calls
  #   auth.ensure_valid_token
  #   
  #   # Token is now available for HTTP requests
  #   token = auth.token
  #
  # @attr_reader [Configuration] config The SharePoint configuration
  # @attr_reader [String] token The current OAuth2 access token
  # @attr_reader [Time] token_expires_at The expiration time of the current token
  #
  # @see M365ActiveStorage::Configuration
  # @see M365ActiveStorage::Http
  class Authentication
    attr_reader :config, :token, :token_expires_at

    # Initialize the Authentication handler
    #
    # @param [Configuration] config The SharePoint configuration object containing
    #                                authentication parameters (auth_host, tenant_id, app_id, secret)
    def initialize(config)
      @config = config
      @token = nil
      @token_expires_at = nil
    end

    # Ensure a valid, non-expired token is available
    #
    # Checks if the current token is nil or expired. If so, obtains a new token
    # from the Azure AD authentication endpoint. This method is called automatically
    # before making API requests.
    #
    # If a valid token already exists and hasn't expired, this method returns immediately.
    #
    # @return [void]
    # @raise [StandardError] if token retrieval fails
    # @example
    #   auth.ensure_valid_token  # Obtains token if needed
    #   puts auth.token  # Token is now available
    #
    # @see #token_expired?
    def ensure_valid_token
      return unless token.blank? || token_expired?

      obtain_app_token
    end

    # Force immediate token expiration
    #
    # Manually expires the current token by setting the expiration time to the past.
    # This is useful for testing or forcing a token refresh.
    #
    # @return [Time] The new expiration time (1 minute in the past)
    # @example
    #   auth.expire_token!
    #   auth.ensure_valid_token  # Will fetch a new token
    #
    # @see #ensure_valid_token
    def expire_token!
      @token_expires_at = Time.current - 1.minute
    end

    private

    # Build the authentication URL for Azure AD
    #
    # Constructs the OAuth2 token endpoint URL from the configured auth host and tenant ID.
    #
    # @return [String] The complete authentication URL
    # @example
    #   # Returns: "https://login.microsoftonline.com/tenant-id/oauth2/v2.0/token"
    def auth_url
      "#{config.auth_host}/#{config.tenant_id}/oauth2/v2.0/token"
    end

    # Parse the authentication URL into a URI object
    #
    # @return [URI] The parsed URI for the authentication endpoint
    def auth_uri
      URI(auth_url)
    end

    # Build the OAuth2 request body
    #
    # Constructs the form-encoded request body for the client credentials flow,
    # including:
    # * Grant type: "client_credentials"
    # * Client ID from configuration
    # * Client secret from configuration
    # * Scope: Microsoft Graph API default scope
    #
    # @return [String] URL-encoded form data
    # @example
    #   # Returns: "grant_type=client_credentials&client_id=...&client_secret=...&scope=..."
    def request_body
      URI.encode_www_form(
        grant_type: "client_credentials",
        client_id: config.app_id,
        client_secret: config.secret,
        scope: "#{config.ms_graph_url}/.default"
      )
    end

    # Obtain a new OAuth2 application token
    #
    # Makes an HTTP request to the Azure AD token endpoint using client credentials.
    # Parses the response and updates the token and expiration time.
    #
    # @return [void]
    # @raise [StandardError] if the token request fails (non-200 response)
    # @example
    #   # Automatically called by ensure_valid_token
    #   auth.send(:obtain_app_token)
    #
    # @see #fetch_token_response
    # @see #parse_token_response
    def obtain_app_token
      response = fetch_token_response
      raise "Failed to obtain SharePoint token" unless response.code.to_i == 200

      parse_token_response(response)
    end

    # Fetch the token response from Azure AD
    #
    # Makes an HTTPS POST request to the Azure AD OAuth2 token endpoint
    # with client credentials.
    #
    # @return [Net::HTTPResponse] The response from the token endpoint
    # @raise [StandardError] if the HTTP request fails
    def fetch_token_response
      http = Net::HTTP.new(auth_uri.host, auth_uri.port)
      http.use_ssl = true
      http.post(auth_uri.request_uri, request_body, { "Content-Type" => "application/x-www-form-urlencoded" })
    end

    # Parse and store the token response from Azure AD
    #
    # Extracts the access token and expiration time from the JSON response.
    # Automatically subtracts 5 minutes from the expiration time as a safety margin
    # to prevent using nearly-expired tokens.
    #
    # @param [Net::HTTPResponse] response The HTTP response from the token endpoint
    # @return [void]
    # @example
    #   response = fetch_token_response
    #   parse_token_response(response)  # Sets @token and @token_expires_at
    def parse_token_response(response)
      token_data = JSON.parse(response.body)
      expires_in = token_data["expires_in"].to_i
      @token = token_data["access_token"]
      @token_expires_at = Time.current + expires_in.seconds - 5.minutes
    end

    # Check if the current token is expired
    #
    # @return [Boolean] true if the token is nil or the expiration time has passed
    def token_expired?
      token_expires_at.nil? || Time.current >= token_expires_at
    end
  end
end
