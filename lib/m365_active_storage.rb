# frozen_string_literal: true

require "m365_active_storage/version"
require "m365_active_storage/railtie"
require "m365_active_storage/m365"

# == M365 Active Storage
#
# Integration gem for Rails Active Storage to use Microsoft 365 (SharePoint) as a storage service.
#
# This gem provides seamless integration between Rails Active Storage and Microsoft 365 SharePoint,
# allowing Rails applications to store files in SharePoint instead of local filesystems or other
# traditional storage providers.
#
# === Features
#
# * Native SharePoint integration via Microsoft Graph API
# * OAuth2 authentication for secure access
# * Full Active Storage compatibility
# * Automatic file management and retrieval
# * Support for file metadata
#
# === Configuration
#
# Configure the gem in your Rails app by adding credentials:
#
#   sharepoint:
#     ms_graph_url: "https://graph.microsoft.com"
#     ms_graph_version: "v1.0"
#     auth_host: "https://login.microsoftonline.com"
#     oauth_tenant: "YOUR_TENANT_ID"
#     oauth_app_id: "YOUR_APP_ID"
#     oauth_secret: "YOUR_CLIENT_SECRET"
#     sharepoint_site_id: "YOUR_SITE_ID"
#     sharepoint_drive_id: "YOUR_DRIVE_ID"
#
# Then set Active Storage to use SharePoint in your environment config:
#
#   config.active_storage.service = :sharepoint
#
# === Usage
#
# Use with Active Storage as normal in your Rails models:
#
#   class Document < ApplicationRecord
#     has_one_attached :file
#   end
#
#   document = Document.new
#   document.file.attach(io: File.open('path/to/file.pdf'), filename: 'document.pdf')
#   document.file.download
#
# === API Reference
#
# * M365ActiveStorage::M365 - Main interface for SharePoint operations
# * M365ActiveStorage::Configuration - Configuration management
# * M365ActiveStorage::Authentication - OAuth2 token handling
# * M365ActiveStorage::Http - HTTP request handling
# * ActiveStorage::Service::SharepointService - Active Storage service implementation
#
module M365ActiveStorage
end
