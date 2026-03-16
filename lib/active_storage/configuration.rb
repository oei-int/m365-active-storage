# frozen_string_literal: true

module M365ActiveStorage
  # == SharePoint Configuration Manager
  #
  # Manages and validates all configuration parameters needed to connect to Microsoft 365 SharePoint
  # via the Microsoft Graph API.
  #
  # === Responsibilities
  #
  # * Load and parse configuration parameters
  # * Validate that all required parameters are present
  # * Provide convenient accessors for configuration values
  # * Raise informative errors for missing or invalid configurations
  #
  # === Required Configuration Parameters
  #
  # * +ms_graph_url+ - The Microsoft Graph API base URL (typically https://graph.microsoft.com)
  # * +ms_graph_version+ - The Graph API version (e.g., "v1.0", "beta")
  # * +auth_host+ - The OAuth2 authentication endpoint (typically https://login.microsoftonline.com)
  # * +tenant_id+ - Your Azure AD tenant ID (directory ID from Azure Portal)
  # * +app_id+ - Your Azure AD application ID (client ID from your app registration)
  # * +secret+ - Your Azure AD client secret
  # * +site_id+ - The target SharePoint site ID
  # * +drive_id+ - The target SharePoint drive ID within the site
  #
  # === Configuration Sources
  #
  # Configuration can be provided via:
  # * Rails credentials (config/credentials.yml.enc)
  # * Environment variables
  # * Direct parameter passing
  #
  # Example in config/storage.yml:
  #
  #   sharepoint:
  #     ms_graph_url: <%= Rails.application.credentials.sharepoint[:ms_graph_url] %>
  #     ms_graph_version: <%= Rails.application.credentials.sharepoint[:ms_graph_version] %>
  #     auth_host: <%= Rails.application.credentials.sharepoint[:auth_host] %>
  #     tenant_id: <%= Rails.application.credentials.sharepoint[:oauth_tenant] %>
  #     app_id: <%= Rails.application.credentials.sharepoint[:oauth_app_id] %>
  #     secret: <%= Rails.application.credentials.sharepoint[:oauth_secret] %>
  #     site_id: <%= Rails.application.credentials.sharepoint[:sharepoint_site_id] %>
  #     drive_id: <%= Rails.application.credentials.sharepoint[:sharepoint_drive_id] %>
  #
  # === Example Usage
  #
  #   config = M365ActiveStorage::Configuration.new(
  #     ms_graph_url: "https://graph.microsoft.com",
  #     ms_graph_version: "v1.0",
  #     auth_host: "https://login.microsoftonline.com",
  #     tenant_id: "your-tenant-id",
  #     app_id: "your-app-id",
  #     secret: "your-client-secret",
  #     site_id: "your-site-id",
  #     drive_id: "your-drive-id"
  #   )
  #
  #   puts config.ms_graph_endpoint  # => "https://graph.microsoft.com/v1.0"
  #
  # @attr_reader [String] ms_graph_url The Microsoft Graph API base URL
  # @attr_reader [String] ms_graph_version The Graph API version
  # @attr_reader [String] ms_graph_endpoint The complete Graph API endpoint (url + version)
  # @attr_reader [String] auth_host The OAuth2 authentication host
  # @attr_reader [String] tenant_id The Azure AD tenant ID
  # @attr_reader [String] app_id The Azure AD application ID
  # @attr_reader [String] secret The Azure AD client secret
  # @attr_reader [String] site_id The SharePoint site ID
  # @attr_reader [String] drive_id The SharePoint drive ID
  class Configuration
    attr_reader :ms_graph_url, :ms_graph_version, :ms_graph_endpoint,
                :auth_host, :tenant_id,
                :app_id, :secret, :site_id, :drive_id

    # Initialize Configuration with the provided parameters
    #
    # All parameters are required. Missing parameters will raise a KeyError
    # with a detailed message listing which parameters are missing.
    #
    # @param [Hash] options The configuration parameters
    # @option options [String] :ms_graph_url The Microsoft Graph API base URL
    # @option options [String] :ms_graph_version The Graph API version
    # @option options [String] :auth_host The OAuth2 authentication host
    # @option options [String] :tenant_id The Azure AD tenant ID
    # @option options [String] :app_id The Azure AD application ID
    # @option options [String] :secret The Azure AD client secret
    # @option options [String] :site_id The SharePoint site ID
    # @option options [String] :drive_id The SharePoint drive ID
    #
    # @raise [KeyError] if any required parameter is missing or empty
    #
    # @example
    #   config = M365ActiveStorage::Configuration.new(
    #     ms_graph_url: "https://graph.microsoft.com",
    #     ms_graph_version: "v1.0",
    #     # ... other required parameters
    #   )
    #
    # @see #validate_configuration!
    def initialize(**options)
      fetch_configuration_params(options)
      validate_configuration!
    rescue KeyError => e
      raise KeyError, "Configuration error: #{e.message}"
    end

    private

    # Extract and store configuration parameters from the options hash
    #
    # Accepts keys in any case (string or symbol) and stores them as instance variables.
    #
    # @param [Hash] options The configuration options hash
    # @return [void]
    # @raise [KeyError] if any required parameter is missing
    def fetch_configuration_params(options)
      options = options.with_indifferent_access
      @auth_host = options.fetch(:auth_host)
      @tenant_id = options.fetch(:tenant_id)
      @app_id = options.fetch(:app_id)
      @secret = options.fetch(:secret)
      @ms_graph_url = options.fetch(:ms_graph_url)
      @ms_graph_version = options.fetch(:ms_graph_version)
      @site_id = options.fetch(:site_id)
      @drive_id = options.fetch(:drive_id)
      @ms_graph_endpoint = "#{@ms_graph_url}/#{@ms_graph_version}"
    end

    # Validate that all required configuration parameters are present and non-empty
    #
    # Checks each configuration parameter and raises a detailed KeyError if any are missing
    # or empty (nil or whitespace-only strings).
    #
    # @return [void]
    # @raise [KeyError] with a detailed message listing all missing parameters
    #
    # @example
    #   # If tenant_id, app_id, and secret are missing:
    #   # Raises:
    #   # KeyError: SharePoint service configuration is incomplete. Missing required parameters::
    #   # - @tenant_id
    #   # - @app_id
    #   # - @secret
    def validate_configuration!
      missing_params = []
      instance_variables.each do |var|
        missing_params << var.to_s.gsub("@", "- ") unless instance_variable_get(var).present?
      end
      return unless missing_params.any?

      missing_params.unshift("SharePoint service configuration is incomplete. Missing required parameters::")
      raise KeyError, missing_params.join("\n")
    end
  end
end
