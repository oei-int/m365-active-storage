# frozen_string_literal: true

module M365ActiveStorage
  # == File Discovery and Loading
  #
  # Utilities for discovering and loading controller and helper files from the gem.
  #
  # === Responsibilities
  #
  # * Discover controller files from the gem installation
  # * Load controller classes into memory
  # * Provide convenient accessors for gem resources
  #
  # === Architecture
  #
  # This class uses Gem.find_files to locate all controller files within the installed gem.
  # This allows the gem to dynamically load controllers without hardcoding file paths.
  #
  # === Example Usage
  #
  #   files = M365ActiveStorage::Files.controller_files
  #   classes = M365ActiveStorage::Files.controller_classes
  #
  # @see M365ActiveStorage::Railtie
  class Files < ::Rails::Engine
    # Get all controller file paths from the gem
    #
    # Searches the installed gem for all Ruby files in the controllers directory.
    # Uses Gem.find_files to locate files regardless of gem installation method.
    #
    # @return [Array<String>] Array of absolute paths to controller files
    #
    # @example
    #   files = M365ActiveStorage::Files.controller_files
    #   # => ["/path/to/gem/lib/m365_active_storage/controllers/blobs_controller.rb", ...]
    def self.controller_files
      Gem.find_files("m365_active_storage/controllers/**/*.rb")
    end

    # Get all controller classes from the gem
    #
    # Loads and returns the constantized controller class objects.
    # First discovers files via #controller_files, then converts file paths
    # to class names and loads them.
    #
    # @return [Array<Class>] Array of controller class objects
    #
    # @example
    #   classes = M365ActiveStorage::Files.controller_classes
    #   # => [M365ActiveStorage::BlobsController]
    #
    # @see #controller_files
    def self.controller_classes
      controller_files.map do |path|
        path.remove("#{root}/lib/").remove("controllers/").remove(".rb").camelize.constantize
      end
    end
  end
end
