## [1.1.1] - 2026-04-10

### Bug Fixes

- Fix controller class discovery in `M365ActiveStorage::Files` so only controllers from the active gem installation are loaded, avoiding invalid constantization and inconsistent behavior when multiple gem copies or versions are present on the load path.
- Fix credential-gated test skipping in `test_helper.rb` to avoid constant lookup errors by comparing class names instead of class constants, making skip behavior stable regardless of test load order.
- Fix SharePoint path encoding to produce valid Graph URLs by encoding spaces as `%20` (not `+`), ensuring file and folder paths with spaces are resolved correctly.
- Fix SharePoint ID not being persisted when blob is created with custom metadata (e.g., `sharepoint_folder`). ID persistence is now deferred to an `after_commit` hook to prevent being overwritten by Active Storage's blob save.

### Security

- Add explicit CSRF protection (`protect_from_forgery`) to `M365ActiveStorage::BlobsController` to address Brakeman security warning and enforce forgery protection posture.

## [1.1.0] - 2026-03-25

### Features

- Add support for organizing files in nested SharePoint folders via `sharepoint_folder` metadata on blob attachments.
- Allow configurable storage key to use either blob key or filename for file storage organization in SharePoint.

### Security

- Patch Stored XSS vulnerability in `action_text-trix` dependency.

## [1.0.0] - 2026-03-16

- Initial release
