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
  # Characters of editor HTML one entry may send; a tafsir entry can run to hundreds of thousands.
  TEXT_LIMIT = 20_000
  HTML_TAGS = %w[p br b strong i em u sup sub span div h1 h2 h3 h4 h5 h6 ul ol li blockquote].freeze

  Unavailable = Data.define(:reason) do
    def serializer = UnavailableResource
  end

  # The language code and direction of a preview's text, for the `lang` and `dir` attributes.
  Locale = Data.define(:code, :direction)

  # A surah a preview can show (`?surah=`), with its ayah count.
  Surah = Data.define(:number, :name, :verses_count)

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
    when 'recitation' then Recitation
    when 'translation', 'tafsir', 'transliteration' then Text
    when 'surah-info', 'ayah-theme', 'ayah-topics', 'similar-ayah', 'mutashabihat', 'morphology',
         'quran-metadata' then Records
    end
  end

  def self.surahs
    Chapter.order(:id).pluck(:id, :name_simple, :verses_count).map do |id, name, count|
      Surah.new(number: id, name:, verses_count: count)
    end
  end

  # The surah `?surah=` names, clamped to 1..114.
  def self.surah(query, surahs)
    surahs.fetch(query['surah'].to_i.clamp(1, surahs.size) - 1)
  end

  # The ayahs `?from=` and `?to=` name within the surah: `size` ayahs from `from` unless `to`
  # says otherwise, and never more than `max`.
  def self.range(query, verses_count, size:, max:)
    from = query['from'].to_i.clamp(1, verses_count)
    last = [from + max - 1, verses_count].min
    to = query['to'].present? ? query['to'].to_i.clamp(from, last) : [from + size - 1, last].min
    [from, to]
  end

  # Editor HTML (translations, tafsirs, surah info, topic descriptions) as the page may show it:
  # text formatting only, no attributes but the language and direction, no links or scripts.
  def self.sanitize(html)
    Rails::HTML5::SafeListSanitizer.new.sanitize(html.to_s, tags: HTML_TAGS, attributes: %w[lang dir])
  end

  # Editor HTML as plain text (word translations, short summaries).
  def self.plain(html)
    Rails::HTML5::FullSanitizer.new.sanitize(html.to_s)
  end

  # The language of a resource's text; a language without a code is `fallback`, one without a
  # direction left to right.
  def self.locale(content, fallback)
    language = content&.language
    Locale.new(code: language&.iso_code.presence || fallback, direction: language&.direction == 'rtl' ? 'rtl' : 'ltr')
  end

  # The start of a long sanitized text and whether it was cut: whole top-level elements while
  # they fit in `limit` characters, or the first element's text cut to the limit when even that
  # one does not fit.
  def self.excerpt(html, limit = TEXT_LIMIT)
    return [html, false] if html.size <= limit

    fragment = Nokogiri::HTML5.fragment(html)
    kept = +''
    fragment.children.each do |node|
      part = node.to_html
      break if kept.size + part.size > limit

      kept << part
    end
    [kept.presence || ERB::Util.html_escape(fragment.text[0, limit]), true]
  end

  def self.font_resolver
    Fonts::UrlResolver.new(cdn_host: QulQuranRecord::CDN_HOST)
  end
end
