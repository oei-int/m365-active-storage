# frozen_string_literal: true

module M365ActiveStorage
  # == Pending Deletion Storage
  #
  # Manages filename mapping during blob deletion to support deferred deletion from SharePoint.
  #
  # === Purpose
  #
  # When an ActiveStorage blob is destroyed, the blob record is deleted from the database
  # immediately. However, the actual file deletion from SharePoint may need to happen
  # asynchronously. This class provides thread-safe storage to maintain the mapping between
  # blob keys and filenames after the blob is deleted so that background workers can
  # retrieve the filename and delete the file from SharePoint.
  #
  # === Thread Safety
  #
  # All operations are protected by a Mutex to ensure thread-safe access in concurrent
  # environments (e.g., multiple Sidekiq workers).
  #
  # === Architecture
  #
  # PendingDelete acts as a temporary in-memory registry. When a blob is destroyed:
  # 1. The before_destroy callback stores the key -> filename mapping
  # 2. A background job retrieves the filename and deletes from SharePoint
  # 3. The mapping is removed from storage
  #
  # Note: This is an in-memory store and will be lost if the process restarts.
  # For production use, consider backing this with Redis or a database table.
  #
  # @see M365ActiveStorage::Railtie
  # @see ActiveStorage::Blob
  class PendingDelete
    # Storage for filename mappings during deletion
    # @private
    @pending_deletes = {}
    # Mutex for thread-safe access to pending_deletes
    # @private
    @mutex = Mutex.new

    # Store a blob key and filename for later retrieval during deletion
    #
    # Thread-safe method to add a key-filename pair to the pending deletion registry.
    # Called by the Railtie before_destroy callback when a blob is deleted.
    #
    # @param [String] key The blob's storage key
    # @param [String] filename The blob's filename
    # @return [void]
    #
    # @example
    #   M365ActiveStorage::PendingDelete.store("abc123", "document.pdf")
    def self.store(key, filename)
      @mutex.synchronize do
        @pending_deletes[key] = filename
      end
    end

    # Retrieve and remove a filename from the pending deletion registry
    #
    # Thread-safe method to get a filename by key and remove it from storage.
    # Called by background deletion workers to get the filename for SharePoint deletion.
    #
    # @param [String] key The blob's storage key
    # @return [String, nil] The stored filename, or nil if not found
    #
    # @example
    #   filename = M365ActiveStorage::PendingDelete.get("abc123")
    #   if filename
    #     delete_from_sharepoint(filename)
    #   end
    def self.get(key)
      @mutex.synchronize do
        @pending_deletes.delete(key)
      end
    end
  end
end
