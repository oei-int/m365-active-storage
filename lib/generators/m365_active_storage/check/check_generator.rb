# frozen_string_literal: true

require "yaml"

module M365ActiveStorage
  module Generators
    # init the m365 active storage gem
    class CheckGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Install M365 Active Storage and configure SharePoint integration"

      # Validate m365 credentials and connectivity by making a test API call to Microsoft Graph
      def check_for_m365_credentials
        m365 = M365.new
        m365.ping?
      rescue RuntimeError => e
        say "MS Graph API connectivity failed.", :red
        say "Please check your credentials and configuration.", :red
        say e.message, :red
        exit
      end

      # Validate that the configured sharepoint site and drive are accessible
      def check_for_site_and_drive
        m365 = M365.new
        site_id, drive_id = m365.config_site_and_drive_id
        site = m365.find_site_by_id(site_id)
        drive = m365.find_sharepoint_drive_by_id(site_id, drive_id) if site
        unless site && drive
          say "Cannot connect to SharePoint site and document library.", :red
          say "Check your site and drive configuration.", :red
          exit
        end
        say "Site: #{site["displayName"]}, drive: #{drive["name"]}", :green
      end

      # Check if the storage service is set to SharePoint. Just notify if not.
      def check_service_set_to_sharepoint
        current_service = Rails.application.config.active_storage.service
        return if current_service == :sharepoint

        say "config.active_storage.service is set to #{current_service}", :yellow
        exit
      end

      # Final message if all checks pass
      def final_message
        say "M365 Active Storage installation completed successfully!", :green
      end
    end
  end
end
