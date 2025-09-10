class ResourcePresenter < ApplicationPresenter
  require "cgi"
  include ResourcesHelper

  def meta_title
    if index?
      'QUL Resources - Download Quran Translations, Tafsir, Audio, and Datasets'
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
      'Explore a curated collection of Quranic digital resources including recitations, tafsir, metadata, themes, and more — designed for developers, researchers, and students.'
    end
  end

  def meta_keywords
    if index?
      'Quran resources, Quran translations, Quran tafsir, Quran datasets, Quran audio recitations'
    elsif show?
      [resource.name, resource.resource_type, "download #{resource.resource_type.humanize}", resource.humanize_cardinality_type, resource.tags].compact_blank.join(', ')
    elsif action_name == 'detail'
      [resource.name, resource.resource_type, "download #{resource.resource_type.humanize}", resource.humanize_cardinality_type, resource.tags].compact_blank.join(', ')
    end
  end

  def generate_resource_description
    verse = load_ayah
    resource_type = resource.resource_type.tr('-', '_').to_sym

    case resource_type
    when :recitation
      "Quran Audio Recitation by #{resource.name} - Download MP3 and Segments Data"
    when :quran_script
      script_type = resource.resource_content.meta_value('text-type')
      if script_type
        text = load_ayah.send(script_type)
        clean_meta_description("#{resource.name}(#{load_ayah.verse_key}) - #{text}")
      else
        "#{resource.name} #{verse} - Download Quran Text in different scripts and formats"
      end
    when :font
      "#{resource.name} - Download Quran Fonts for Arabic and Quranic Text"
    when :quran_metadata
      "#{resource.name} - Download Quran Metadata"
    when :surah_info
      if info = ChapterInfo.where(resource_content_id: resource.resource_content_id, chapter_id: verse.chapter_id).first
        clean_meta_description(info.text)
      else
        "#{resource.name} - Download Quran Surah Information"
      end
    when :ayah_topics
      "#{resource.name} - Download Quran Ayah Topics and Thematic Index"
    when :morphology
      # TODO: Find the morphology data for the specific verse
      "#{resource.name} - Download Quran Morphological Data"
    when :mutashabihat
      "#{resource.name} - Download Quran Mutashabihat Data"
    when :similar_ayah
      "#{resource.name} - Download Quran Similar Ayah Data"
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