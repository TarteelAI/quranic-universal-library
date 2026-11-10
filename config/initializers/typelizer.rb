# frozen_string_literal: true

# TypeScript prop types from the Alba serializers in app/serializers, and typed route helpers
# for the routes the new pages link to. Both are committed; `bin/rails typelizer:check` fails
# when they are stale.
Typelizer.configure do |config|
  config.output_dir = Rails.root.join('app/frontend/types/serializers')
  config.types_import_path = '@/types/serializers'

  config.routes.enabled = true
  config.routes.output_dir = Rails.root.join('app/frontend/routes')
  config.routes.include = [
    %r{\A/__dev/},
    %r{\A/users/sign_(in|out)\z},
    %r{\A/\z},
    # The catalog, its type pages and the resource detail pages.
    ->(route) { route[:verb] == 'get' && route[:path].match?(%r{\A/resources(/:type(/:id)?)?\z}) }
  ]
end
