Rails.application.routes.draw do
  # Override default Active Storage blob route to use our authenticated controller
  # This must come BEFORE the default activeStorage routes
  get "/rails/active_storage/blobs/:signed_id/*filename",
      to: "m365_active_storage/blobs#show",
      constraints: { signed_id: /[^\/]+--[^\/]+/ }
end