# frozen_string_literal: true

require "m365_active_storage/files"
require "m365_active_storage/pending_delete"
require "active_storage/service/sharepoint_service"
require "action_controller"
require "action_view"

# require helpers and controllers
M365ActiveStorage::Files.controller_files.each { |path| require path }

module M365ActiveStorage
  # == Rails Integration and Railtie
  #
  # Integrates the m365_active_storage gem into Rails application lifecycle.
  #
  # === Responsibilities
  #
  # * Register gem components with Rails during initialization
  # * Load helper and controller classes
  # * Add callbacks to ActiveStorage::Blob for SharePoint integration
  # * Manage file deletion from SharePoint
  #
  # === Initialization Hooks
  #
  # The Railtie hooks into the +after_initialize+ event to:
  # 1. Load all controller and helper classes from the gem
  # 2. Extend ActiveStorage::Blob with SharePoint-specific before_destroy callback
  # 3. Capture filename information before blob deletion for delayed deletion from SharePoint
  #
  # === File Deletion Flow
  #
  # When a blob is destroyed and it's using the SharePoint service:
  # 1. The before_destroy callback captures the blob's filename
  # 2. Stores it in PendingDelete for later retrieval
  # 3. The filename can be used by the async deletion worker to clean up SharePoint
  #
  # @see M365ActiveStorage::Files
  # @see M365ActiveStorage::PendingDelete
  # @see ActiveStorage::Service::SharepointService
  class Railtie < ::Rails::Railtie
    # Hook into Rails initialization to set up gem components
    config.after_initialize do
      # Add before_destroy callback to ActiveStorage::Blob to capture filename
      ::ActiveStorage::Blob.class_eval do
        before_destroy :store_filename_for_deletion, if: proc { |blob| blob.service.is_a?(::ActiveStorage::Service::SharepointService) }

        private

        # Store the filename in the pending deletes storage before the blob is destroyed
        #
        # This callback is triggered before a blob is destroyed from the database.
        # It captures the blob's filename and stores it in PendingDelete so that
        # asynchronous deletion processes can move the file to the recycle bin
        # in SharePoint.
        #
        # @return [void]
        def store_filename_for_deletion
          M365ActiveStorage::PendingDelete.store(key, filename.to_s)
        end
      end
    end
  end
end

