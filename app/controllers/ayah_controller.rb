class AyahController < ApplicationController
  def show
    @ayah = Verse.find_by(verse_key: params[:key])

    if request.xhr? || request.format.turbo_stream?
      render layout: false
    end
  end

  def text
    @ayah = Verse.find_by(verse_key: params[:key])
    return head :not_found unless @ayah

    requested = [
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

    extra = [
      ['code_v1', 'V1'],
      ['code_v2', 'V2'],
      ['code_v4', 'V4'],
      ['image', 'Images']
    ]

    @scripts = (requested + extra).uniq { |pair| pair.first }

    @script = params[:script].presence || 'text_qpc_hafs'
    @script_label = @scripts.to_h[@script] || @script

    render partial: 'ayah/ayah_text', layout: false
  end

  def translations
    @ayah = Verse.find_by(verse_key: params[:key])
    return head :not_found unless @ayah

    ids = params[:translation_ids]
    ids = [131] if ids.blank?
    @translation_ids = Array(ids).map(&:to_i).uniq

    @translation_resources = ResourceContent.translations.one_verse.approved.order(:priority, :id)
    @translation_resources_by_id = @translation_resources.index_by(&:id)
    @translations = @ayah.translations.where(resource_content_id: @translation_ids).includes(:language, :foot_notes).to_a
    @translation_html = {}
    @footnotes_by_resource_id = {}

    @translations.each do |tr|
      html = tr.text.to_s
      fragment = Nokogiri::HTML::DocumentFragment.parse(html)
      fragment.css('sup[foot_note]').each do |node|
        fid = node['foot_note'].to_s
        next if fid.blank?
        node['data-action'] = [node['data-action'], 'click->translation-footnote-toggle#toggle'].compact.join(' ')
        node['data-footnote-id'] = fid
        node['class'] = [node['class'], 'tw-cursor-pointer tw-text-blue-700'].compact.join(' ')
      end
      @translation_html[tr.resource_content_id] = fragment.to_html
      @footnotes_by_resource_id[tr.resource_content_id] = tr.foot_notes.index_by { |f| f.id.to_s }
    end

    render partial: 'ayah/translations', layout: false
  end

  def tafsirs
    @ayah = Verse.find_by(verse_key: params[:key])
    return head :not_found unless @ayah

    @tafsir_resources = ResourceContent.tafsirs.approved.order(:priority, :id)
    @tafsir_resources_by_id = @tafsir_resources.index_by(&:id)

    ids = params[:tafsir_ids]
    default_id = @tafsir_resources.first&.id
    ids = [default_id] if ids.blank? && default_id.present?
    @tafsir_ids = Array(ids).map(&:to_i).uniq

    @tafsirs = Tafsir
      .where(archived: false)
      .where(resource_content_id: @tafsir_ids)
      .where('start_verse_id <= ? AND end_verse_id >= ?', @ayah.id, @ayah.id)
      .includes(:language)
      .to_a

    @tafsir_by_resource_id = {}
    @tafsirs.each do |t|
      @tafsir_by_resource_id[t.resource_content_id] ||= t
    end

    ranges = []
    @tafsir_by_resource_id.values.each do |t|
      next unless t.start_verse_id.present? && t.end_verse_id.present?
      next unless t.start_verse_id != t.end_verse_id
      ranges << [t.start_verse_id, t.end_verse_id]
    end

    ids = ranges.flat_map { |a, b| a <= b ? (a..b).to_a : (b..a).to_a }.uniq
    verses_by_id = ids.any? ? Verse.where(id: ids).select(:id, :verse_key, :verse_index, :text_qpc_hafs).to_a.index_by(&:id) : {}

    @tafsir_ayahs_by_resource_id = {}
    @tafsir_by_resource_id.values.each do |t|
      next unless t.start_verse_id.present? && t.end_verse_id.present?
      next unless t.start_verse_id != t.end_verse_id
      a = [t.start_verse_id, t.end_verse_id].min
      b = [t.start_verse_id, t.end_verse_id].max
      verses = (a..b).map { |vid| verses_by_id[vid] }.compact.sort_by(&:verse_index)
      @tafsir_ayahs_by_resource_id[t.resource_content_id] = verses
    end

    render partial: 'ayah/tafsirs', layout: false
  end

  def words
    @ayah = Verse.find_by(verse_key: params[:key])
    return head :not_found unless @ayah

    @word_translation_resources = ResourceContent.translations.one_word.approved.order(:priority, :id)
    @word_translation_resources_by_id = @word_translation_resources.index_by(&:id)

    selected = params[:word_translation_id]
    default_id = @word_translation_resources.first&.id
    selected = default_id if selected.blank? && default_id.present?
    @word_translation_id = selected.to_i

    @words = @ayah.words.words.includes(:word_translation).to_a
    @word_translations = WordTranslation.where(word_id: @words.map(&:id), resource_content_id: @word_translation_id).to_a
    @word_translation_by_word_id = @word_translations.index_by(&:word_id)

    render partial: 'ayah/words', layout: false
  end
end