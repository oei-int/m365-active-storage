# frozen_string_literal: true

require "active_storage/configuration"
require "active_storage/authentication"
require "active_storage/http"

module M365ActiveStorage
  # == M365 SharePoint Interface
  #
  # Provides high-level interface for interacting with Microsoft 365 SharePoint services.
  # This class handles configuration loading, authentication, and basic SharePoint operations.
  #
  # === Responsibilities
  #
  # * Load and manage SharePoint configuration from config/storage.yml
  # * Establish authenticated connections to Microsoft Graph API
  # * Provide methods for site and drive discovery
  # * Validate SharePoint endpoint connectivity
  #
  # === Example Usage
  #
  #   m365 = M365ActiveStorage::M365.new
  #   site_id, drive_id = m365.config_site_and_drive_id
  #
  #   site = m365.find_site_by_id(site_id)
  #   drive = m365.find_sharepoint_drive_by_id(site_id, drive_id)
  #
  #   if m365.ping?
  #     puts "SharePoint connectivity is healthy"
  #   end
  #
  # === Configuration
  #
  # Configuration is loaded from config/storage.yml. Required parameters:
  # * ms_graph_url: The Microsoft Graph API base URL
  # * ms_graph_version: The Graph API version (e.g., "v1.0")
  # * auth_host: The OAuth2 authentication endpoint
  # * oauth_tenant: Your Azure AD tenant ID
  # * oauth_app_id: Your Azure AD application ID
  # * oauth_secret: Your Azure AD client secret
  # * sharepoint_site_id: The target SharePoint site ID
  # * sharepoint_drive_id: The target SharePoint drive ID
  #
  # @attr_reader [Configuration] config The loaded configuration
  # @attr_reader [Authentication] auth The authentication handler
  # @attr_reader [Http] http The HTTP request handler
  class M365
    attr_reader :auth, :http, :config
    private :auth, :http, :config

    # Initialize the M365 interface and load configuration
    #
    # Loads configuration from config/storage.yml and establishes
    # authentication and HTTP handler instances.
    #
    # @raise [KeyError] if required configuration parameters are missing
    # @raise [RuntimeError] if storage.yml is not found
    def initialize
      @config = Configuration.new(**M365.load_configuration_from_storage_yml)
      @auth = Authentication.new(@config)
      @http = Http.new(@auth)
    rescue KeyError => e
      raise e.message
    end

    # Returns the configured site ID and drive ID as an array
    #
    # @return [Array<String>] A two-element array containing [site_id, drive_id]
    # @example
    #   site_id, drive_id = m365.config_site_and_drive_id
    def config_site_and_drive_id
      [config.site_id, config.drive_id]
    end

    # Find a SharePoint site by its ID
    #
    # Queries the Microsoft Graph API to retrieve information about a specific SharePoint site.
    # Requires valid authentication token.
    #
    # @param [String] site_id The SharePoint site ID to retrieve
    # @return [Hash, nil] A hash containing site information, or nil if the site is not found
    # @raise [StandardError] if authentication fails
    # @example
    #   site = m365.find_site_by_id("site123")
    #   if site
    #     puts "Site: #{site['displayName']}"
    #   end
    def find_site_by_id(site_id)
      auth.ensure_valid_token
      url = "#{auth.config.ms_graph_endpoint}/sites/#{site_id}"
      response = http.get(url)
      return nil unless response.code.to_i == 200

      JSON.parse(response.body)
    end

    # Find a SharePoint drive within a specific site
    #
    # Retrieves information about a drive associated with a SharePoint site.
    # Requires valid authentication token and valid site and drive IDs.
    #
    # @param [String] site_id The SharePoint site ID
    # @param [String] drive_id The SharePoint drive ID within that site
    # @return [Hash, nil] A hash containing drive information, or nil if the drive is not found
    # @raise [StandardError] if authentication fails
    # @example
    #   drive = m365.find_sharepoint_drive_by_id("site123", "drive456")
    #   if drive
    #     puts "Drive: #{drive['name']}"
    #   end
    def find_sharepoint_drive_by_id(site_id, drive_id)
      auth.ensure_valid_token
      url = "#{auth.config.ms_graph_endpoint}/sites/#{site_id}/drives/#{drive_id}"
      response = http.get(url)
      return nil unless response.code.to_i == 200

      JSON.parse(response.body)
    end

    # Check SharePoint endpoint connectivity and configuration validity
    #
    # Performs a simple health check by querying the SharePoint sites endpoint.
    # This validates that authentication is working and the SharePoint service is accessible.
    #
    # @return [Boolean] true if the endpoint is accessible, false otherwise
    # @example
    #   if m365.ping?
    #     puts "SharePoint is accessible"
    #   else
    #     puts "Cannot reach SharePoint"
    #   end
    def ping?
      auth.ensure_valid_token
      url = "#{auth.config.ms_graph_endpoint}/sites/root/sites"
      response = http.get(url)
      response.code.to_i == 200
    end

    # Load configuration from config/storage.yml file
    #
    # Reads and parses the Rails storage configuration file, evaluating any ERB templates
    # and extracting the SharePoint-specific configuration.
    #
    # @return [Hash] The SharePoint configuration parameters
    # @raise [RuntimeError] if storage.yml does not exist
    # @raise [RuntimeError] if storage.yml does not contain a "sharepoint" key
    # @raise [KeyError] if required configuration parameters are missing
    # @see M365ActiveStorage::Configuration for required parameters
    def self.load_configuration_from_storage_yml
      storage_yml = Rails.root.join("config", "storage.yml")
      raise "Missing storage.yml configuration file" unless File.exist?(storage_yml)

      erb_template = ERB.new(File.read(storage_yml))
      yaml_content = erb_template.result(binding)
      configuration = YAML.safe_load(yaml_content, permitted_classes: [Regexp], aliases: true)
      raise "Invalid sharepoint storage.yml configuration" unless configuration&.key?("sharepoint")

      configuration["sharepoint"]
    end
  end
end
