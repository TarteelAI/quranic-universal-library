# frozen_string_literal: true

# Inertia pages (app/frontend) render through InertiaController and the `inertia` layout.
# The options below are the ones the Inertia v3 client expects.
InertiaRails.configure do |config|
  # The version also names the page groups: the shared navigation is a once prop and says which
  # links new pages serve, so a tab loaded under another setting reloads in full on its next visit.
  assets_digest = ViteRuby.digest
  config.version = -> { [assets_digest, *PageGroups.enabled].join('-') }
  config.always_include_errors_hash = true
  config.use_script_element_for_initial_page = true
  config.use_data_inertia_head_attribute = true
  config.server_head = true
  config.xsrf_cookie_refresh = :lazy

  # SSR: in development the Vite dev server renders it (@inertiajs/vite). In production the
  # SSR bundle (public/vite-ssr) runs as the `inertia-ssr` runit service on localhost:13714
  # (docker/inertia-ssr.run). When the service is down or slow, the page renders in the
  # browser, and the error goes to the Rails log and to Rails.error.
  config.ssr_enabled = !Rails.env.test?

  # A Passenger worker waits for the SSR answer, so give up quickly.
  config.ssr_timeout = 2 if Rails.env.production?
end
