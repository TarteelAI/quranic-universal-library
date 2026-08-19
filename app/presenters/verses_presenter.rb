class VersesPresenter < ApplicationPresenter
  def verses
    @verses ||= begin
      ids = verse_ids
      list = Verse.where(id: ids)
                  .includes(:words)
                  .order(Arel.sql("ARRAY_POSITION(ARRAY[#{ids.map { |k| "'#{k}'" }.join(",")}]::text[], verses.id::text)"))

      if show_translation?
        list = list
                 .eager_load(:translations)
                 .where(translations: { resource_content_id: translation_ids })
                 .order('words.position ASC')
      end

      list
    end
  end

  def script
    @script ||= begin
      selected = params[:script].to_s
      available_scripts.key?(selected) ? selected : 'text_qpc_hafs'
    end
  end

  def available_scripts
    @available_scripts ||= QuranScriptsComparisonPresenter::SCRIPT_DISPLAY_NAMES.select do |column, _name|
      column.start_with?('text_') && Word.column_names.include?(column)
    end
  end

  def translation_ids
    @translation_ids ||= begin
      ids = params[:resource_ids]
      if ids.blank?
        []
      else
        ids = ids.is_a?(Array) ? ids.compact_blank : ids.split(',').compact_blank
        ids.first(10)
      end
    end
  end

  def show_translation?
    return @show_translation if defined?(@show_translation)

    @show_translation = translation_ids.present? &&
      ResourceContent.translations.where(id: translation_ids).present?
  end

  def common_words
    @common_words ||= begin
      word_sets = verses.map do |verse|
        verse.words.map do |word|
          word.send(script).to_s.split(' ').map(&:remove_diacritics)
        end
      end

      word_sets.flatten.group_by(&:itself).select { |_word, list| list.size > 1 }.keys.to_set
    end
  end

  def meta_title
    "Compare Ayah"
  end

  def meta_description
    'Compare multiple Ayahs side by side, with optional translations, to explore similarities in wording and structure.'
  end

  def meta_keywords
    'quran, quran translation, quran tafsir, multilingual quran, online quran library, quranic tools, ayah comparison'
  end

  protected

  def verse_ids
    return [] unless params[:ayahs].present?

    ids = []

    params[:ayahs].to_s.split(',').map(&:strip).each do |part|
      if part.include?('-')
        from, to = part.split('-')
        from = Utils::Quran.get_ayah_id_from_key(from.strip)
        to = Utils::Quran.get_ayah_id_from_key(to.strip)
        ids += (from..to).to_a if from && to
      elsif part.match?(/^\d+:\d+$/)
        ids << Utils::Quran.get_ayah_id_from_key(part)
      end
    end

    ids.uniq
  end
end
