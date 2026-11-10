# frozen_string_literal: true

# Base for every serializer. Keys are camelCase, as the TypeScript side reads them.
class ApplicationResource
  include Alba::Resource
  include Typelizer::DSL

  helper Alba::Inertia::Resource

  transform_keys :lower_camel
end
