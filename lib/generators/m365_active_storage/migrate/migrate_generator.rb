# frozen_string_literal: true

require "yaml"

module M365ActiveStorage
  module Generators
    # Migrate from local to M365 SharePointActive Storage
    class MigrateGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Migrate from local to M365 SharePointActive Storage "

      # Migrate all files from local storage to sharepoint
      def migrate_to_sharepoint_service
        service = ActiveStorage::Service::SharepointService.new(**M365.load_configuration_from_storage_yml)
        active_storage_blobs("local").each { |blob| migrate_blob(service, blob) }
      end

      private

      # Migrate a single blob to the new service and update the blobs to point to the new service
      def migrate_blob(service, blob)
        print "#{blob.filename} "
        service.upload(blob.key, StringIO.new(blob.download), checksum: blob.checksum)
        blob.update!(service_name: "sharepoint")
        say "Done", :green
      rescue StandardError => e
        say "Failed: #{e.message}", :red
      end

      # Get all blobs from the source service and return them. Exit the migration if no blobs are found.
      def active_storage_blobs(source_service_name)
        blobs = ActiveStorage::Blob.where(service_name: source_service_name)
        say "No files found in #{source_service_name} storage. Nothing to migrate.", :yellow and exit if blobs.empty?
        say "#{blobs.count} blobs to migrate", :yellow
        blobs
      end
    end
  end
end
