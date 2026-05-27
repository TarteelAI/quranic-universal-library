class ResourcePresenter < ApplicationPresenter
  require "cgi"
  include ResourcesHelper

  def meta_title
    if index?
      'QUL Resources — Download Quran Data: Translations, Tafsir, Audio, Scripts & JSON Datasets'
    elsif show?
      @resource.group_info
    elsif action_name == 'related_resources'
    elsif action_name == 'detail'
      @resource.humanize
    end
  end

  def meta_description
    if show?
      resource_key = resource.resource_type.tr('-', '_').to_sym
      card = downloadable_resource_cards[resource_key]
      if card
        card.description
      end
    elsif action_name == 'detail'
      generate_resource_description
    else
      'Download a curated collection of Quran data as JSON — recitations, translations, tafsir, word-by-word, Uthmani/IndoPak scripts, metadata and themes — for developers, researchers and students.'
    end
  end

  def meta_keywords
    global_keywords = ['Quran data', 'Quran json data', 'download Quran data']

    if index?
      (['Quran resources', 'Quran translations json', 'Quran tafsir json', 'Quran datasets', 'Quran audio recitations', 'Uthmani script json'] + global_keywords).join(', ')
    elsif show? || action_name == 'detail'
      ([resource.name, "#{resource.name} json data", resource.resource_type, "download #{resource.resource_type.humanize}", resource.humanize_cardinality_type, resource.tags] + global_keywords).compact_blank.join(', ')
    end
  end

  def generate_resource_description
    verse = load_ayah
    resource_type = resource.resource_type.tr('-', '_').to_sym

    case resource_type
    when :recitation
      "Download Quran audio recitation by #{resource.name} — MP3 files and word-by-word segment data as JSON for every ayah."
    when :quran_script
      "Download #{resource.name} Quran script as JSON — Uthmani/IndoPak verse and word text data for every ayah."
    when :font
      "Download #{resource.name} — Quran fonts for Arabic and Quranic text, with glyph code-point data."
    when :quran_metadata
      "Download #{resource.name} — Quran metadata as JSON data (surah, ayah, juz, page and more)."
    when :surah_info
      if info = ChapterInfo.where(resource_content_id: resource.resource_content_id, chapter_id: verse.chapter_id).first
        clean_meta_description(info.text)
      else
        "#{resource.name} - Download Quran Surah Information"
      end
    when :ayah_topics
      "Download #{resource.name} — Quran ayah topics and thematic index as JSON data."
    when :morphology
      # TODO: Find the morphology data for the specific verse
      "Download #{resource.name} — Quran morphological data as JSON."
    when :mutashabihat
      "Download #{resource.name} — Quran mutashabihat (similar ayah) data as JSON."
    when :similar_ayah
      "Download #{resource.name} — Quran similar ayah data as JSON."
    when :ayah_theme
      theme = AyahTheme.for_verse(load_ayah)
      if theme
        clean_meta_description("#{resource.name}(#{verse.verse_key}) - #{theme.theme}")
      else
        "#{resource.name} - Download Quran Ayah Theme Data"
      end
    else
      ""
    end
  end

  def load_ayah(fallback_key: '1:1')
    key = params[:ayah] || fallback_key
    Verse.includes(:chapter).find_by_id_or_key(key)
  end

  def load_surah
    if v = load_ayah
      v.chapter
    end
  end

  def verse_number
    if v = load_ayah
      v.verse_number
    end
  end

  def clean_meta_description(text, max_length = 160)
    return "" if text.nil?

    # 1. Remove all HTML tags (including attributes)
    cleaned = text.gsub(/<[^>]*>/, "")

    # 2. Decode HTML entities (requires CGI)
    cleaned = CGI.unescapeHTML(cleaned)

    # 3. Normalize whitespace and line breaks
    cleaned = cleaned.gsub(/[\r\n]+/, "\n")

    # 4. If already short enough, return
    return cleaned if cleaned.length <= max_length

    # 5. Prefer sentence end before limit
    truncated = cleaned[0...max_length]
    if truncated =~ /(.*?[.!?])[^.!?]*$/
      return $1.strip
    end

    # 6. Otherwise cut at the last space
    truncated = truncated.rpartition(" ").first
    truncated.strip + "…"
  end
end