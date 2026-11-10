# frozen_string_literal: true

# Inertia pages (app/frontend) render through InertiaController and the `inertia` layout.
# The options below are the ones the Inertia v3 client expects.
InertiaRails.configure do |config|
  config.version = ViteRuby.digest
  config.always_include_errors_hash = true
  config.use_script_element_for_initial_page = true
  config.use_data_inertia_head_attribute = true
  config.server_head = true
  config.xsrf_cookie_refresh = :lazy

  # In development the Vite dev server renders SSR (@inertiajs/vite). Production SSR is
  # a separate Node service (story 001-03).
  config.ssr_enabled = Rails.env.development?
end
