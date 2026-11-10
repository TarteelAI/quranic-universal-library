# frozen_string_literal: true

# The Preview tab of a resource: what one page or one surah of the resource looks like.
#
# One provider per kind of resource builds a plain value from the resource and the query string
# (`page`, `surah`, `from`, `to`, `view`); it knows nothing of controllers, Inertia or the session,
# so the public API can serve the same previews. A provider returns its preview, or an
# Unavailable with the reason when the resource cannot be shown (no font, no word rows). A type
# without a provider has no preview (nil).
module Previews
  QUERY_KEYS = %w[page surah from to view].freeze

  Unavailable = Data.define(:reason) do
    def serializer = UnavailableResource
  end

  def self.for(resource, query = {})
    provider(resource.resource_type)&.new(resource, query.to_h.stringify_keys)&.call
  end

  # The preview as the props the page reads.
  def self.as_json(preview)
    preview&.then { |value| value.serializer.new(value).serializable_hash }
  end

  def self.provider(type)
    case type
    when 'mushaf-layout' then MushafLayout
    when 'font' then Font
    when 'quran-script' then Script
    end
  end

  def self.font_resolver
    Fonts::UrlResolver.new(cdn_host: QulQuranRecord::CDN_HOST)
  end
end
