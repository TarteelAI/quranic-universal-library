class AyahPresenter < ApplicationPresenter
  def ayah
    @ayah ||= Verse.find_by(verse_key: params[:key])
  end

  def found?
    ayah.present?
  end

  def scripts
    text_scripts = [
      ['text_uthmani', 'Uthmani (Me Quran)'],
      ['text_indopak', 'Indopak'],
      ['text_imlaei_simple', 'Imlaei (Without tashkeel)'],
      ['text_imlaei', 'Imlaei (Simple)'],
      ['text_uthmani_simple', 'Uthmani (Simple)'],
      ['text_uthmani_tajweed', 'QPC Hafs Tajweed (Unicode)'],
      ['text_qpc_hafs', 'QPC Hafs'],
      ['text_indopak_nastaleeq', 'Indopak Nastaleeq'],
      ['text_qpc_nastaleeq', 'QPC Nastaleeq'],
      ['text_qpc_nastaleeq_hafs', 'QPC Nastaleeq Hafs'],
      ['text_digital_khatt', 'Digital Khatt v2'],
      ['text_digital_khatt_v1', 'Digital Khatt v1'],
      ['text_qpc_hafs_tajweed', 'QPC Hafs Tajweed'],
      ['text_digital_khatt_indopak', 'Digital Khatt Indopak']
    ]

    glyph_scripts = [
      ['code_v1', 'V1'],
      ['code_v2', 'V2'],
      ['code_v4', 'V4'],
      ['image', 'Images']
    ]

    text_scripts + glyph_scripts
  end

  def script
    params[:script].presence || 'text_qpc_hafs'
  end

  def script_label
    scripts.to_h[script] || script
  end

  def translation_ids
    ids = params[:translation_ids]
    ids = [131] if ids.blank?
    Array(ids).map(&:to_i).uniq
  end

  def translation_resources
    @translation_resources ||= ResourceContent.translations.one_verse.approved.order(:priority, :id)
  end

  def translation_resources_by_id
    @translation_resources_by_id ||= translation_resources.index_by(&:id)
  end

  def translation_resources_grouped_by_language
    @translation_resources_grouped_by_language ||= translation_resources.includes(:language).group_by do |resource|
      resource.language&.name&.titleize || 'Unknown'
    end.sort_by { |language, _| language }.to_h
  end

  def translations
    return [] unless found?
    @translations ||= ayah.translations.where(resource_content_id: translation_ids).includes(:language, :foot_notes).to_a
  end

  def translation_html_by_id
    return {} unless translations.any?
    return @translation_html_by_id if defined?(@translation_html_by_id)

    @translation_html_by_id = {}
    translations.each do |tr|
      html = tr.text.to_s
      fragment = Nokogiri::HTML::DocumentFragment.parse(html)
      fragment.css('sup[foot_note]').each do |node|
        fid = node['foot_note'].to_s
        next if fid.blank?
        node['data-action'] = [node['data-action'], 'click->translation-footnote-toggle#toggle'].compact.join(' ')
        node['data-footnote-id'] = fid
        node['class'] = [node['class'], 'tw-cursor-pointer tw-text-blue-700'].compact.join(' ')
      end
      @translation_html_by_id[tr.resource_content_id] = fragment.to_html
    end
    @translation_html_by_id
  end

  def translation_footnotes_by_id
    return {} unless translations.any?
    return @translation_footnotes_by_id if defined?(@translation_footnotes_by_id)

    @translation_footnotes_by_id = {}
    translations.each do |tr|
      @translation_footnotes_by_id[tr.resource_content_id] = tr.foot_notes.index_by { |f| f.id.to_s }
    end
    @translation_footnotes_by_id
  end

  def tafsir_resources
    @tafsir_resources ||= ResourceContent.tafsirs.approved.order(:priority, :id)
  end

  def tafsir_resources_by_id
    @tafsir_resources_by_id ||= tafsir_resources.index_by(&:id)
  end

  def tafsir_ids
    ids = params[:tafsir_ids]
    default_id = tafsir_resources.first&.id
    ids = [default_id] if ids.blank? && default_id.present?
    Array(ids).map(&:to_i).uniq
  end

  def tafsirs
    return [] unless found?
    @tafsirs ||= Tafsir
      .where(archived: false)
      .where(resource_content_id: tafsir_ids)
      .where('start_verse_id <= ? AND end_verse_id >= ?', ayah.id, ayah.id)
      .includes(:language)
      .to_a
  end

  def tafsir_by_id
    return {} unless tafsirs.any?
    return @tafsir_by_id if defined?(@tafsir_by_id)

    @tafsir_by_id = {}
    tafsirs.each do |t|
      @tafsir_by_id[t.resource_content_id] ||= t
    end
    @tafsir_by_id
  end

  def tafsir_ayahs_by_id
    return {} if tafsir_by_id.blank?
    return @tafsir_ayahs_by_id if defined?(@tafsir_ayahs_by_id)

    ranges = []
    tafsir_by_id.values.each do |t|
      next unless t.start_verse_id.present? && t.end_verse_id.present?
      next unless t.start_verse_id != t.end_verse_id
      ranges << [t.start_verse_id, t.end_verse_id]
    end

    ids = ranges.flat_map { |a, b| a <= b ? (a..b).to_a : (b..a).to_a }.uniq
    verses_by_id = ids.any? ? Verse.where(id: ids).select(:id, :verse_key, :verse_index, :text_qpc_hafs).to_a.index_by(&:id) : {}

    @tafsir_ayahs_by_id = {}
    tafsir_by_id.values.each do |t|
      next unless t.start_verse_id.present? && t.end_verse_id.present?
      next unless t.start_verse_id != t.end_verse_id
      a = [t.start_verse_id, t.end_verse_id].min
      b = [t.start_verse_id, t.end_verse_id].max
      verses = (a..b).map { |vid| verses_by_id[vid] }.compact.sort_by(&:verse_index)
      @tafsir_ayahs_by_id[t.resource_content_id] = verses
    end
    @tafsir_ayahs_by_id
  end

  def word_translation_resources
    @word_translation_resources ||= ResourceContent.translations.one_word.approved.order(:priority, :id)
  end

  def word_translation_resources_by_id
    @word_translation_resources_by_id ||= word_translation_resources.index_by(&:id)
  end

  def word_translation_id
    selected = params[:word_translation_id]
    default_id = word_translation_resources.first&.id
    selected = default_id if selected.blank? && default_id.present?
    selected.to_i
  end

  def words
    return [] unless found?
    @words ||= ayah.words.words.to_a
  end

  def word_translations
    return [] if words.empty?
    @word_translations ||= WordTranslation.where(word_id: words.map(&:id), resource_content_id: word_translation_id).to_a
  end

  def word_translation_by_word_id
    return {} unless word_translations.any?
    @word_translation_by_word_id ||= word_translations.index_by(&:word_id)
  end

  def ayah_theme
    return nil unless found?
    @ayah_theme ||= AyahTheme.for_verse(ayah)
  end

  def ayah_theme_ayahs
    return [] unless ayah_theme
    @ayah_theme_ayahs ||= ayah_theme.ayahs.select(:id, :verse_key, :verse_index, :text_qpc_hafs).to_a
  end

  def transliteration_resources
    @transliteration_resources ||= ResourceContent.transliteration.one_verse.approved.order(:priority, :id)
  end

  def transliteration_resources_by_id
    @transliteration_resources_by_id ||= transliteration_resources.index_by(&:id)
  end

  def transliteration_id
    selected = params[:transliteration_id]
    default_id = transliteration_resources.first&.id
    selected = default_id if selected.blank? && default_id.present?
    selected.to_i
  end

  def transliteration
    return nil unless found?
    @transliteration ||= Transliteration.where(resource_type: 'Verse', resource_id: ayah.id, resource_content_id: transliteration_id).first
  end

  def topics
    return [] unless found?
    @topics ||= ayah.topics.to_a
  end

  def topic_modal_url(topic_id)
    return '' unless found?
    context.ayah_topic_path(key: ayah.verse_key, topic_id: topic_id)
  end

  def recitation_resources
    @recitation_resources ||= ResourceContent.recitations.approved.order(:priority, :id)
  end

  def recitation_resources_by_id
    @recitation_resources_by_id ||= recitation_resources.index_by(&:id)
  end

  def recitation_resource_id
    selected = params[:recitation_resource_id]
    default_id = recitation_resources.first&.id
    selected = default_id if selected.blank? && default_id.present?
    selected.to_i
  end

  def recitation_resource
    @recitation_resource ||= recitation_resources_by_id[recitation_resource_id]
  end

  def recitation
    return nil unless recitation_resource
    @recitation ||= if recitation_resource.one_ayah?
                      Recitation.find_by(resource_content_id: recitation_resource.id)
                    else
                      Audio::Recitation.find_by(resource_content_id: recitation_resource.id)
                    end
  end

  def recitation_controller
    return '' unless recitation_resource
    recitation_resource.one_ayah? ? 'ayah-segment-player' : 'surah-segment-player'
  end
end


