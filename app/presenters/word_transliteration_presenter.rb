class WordTransliterationPresenter < ResourcePresenter
  def resource
    @resource ||= if params[:resource_id].present?
                    word_transliteration_resources.find(params[:resource_id])
                  else
                    word_transliteration_resources.first!
                  end
  end

  def word_transliteration_resources
    ResourceContent.transliteration.one_word.order(:priority, :id)
  end

  def verses
    @verses ||= paginate(filtered_verses)
  end

  def verse
    return @verse if defined?(@verse)

    @verse = Verse.find_by(id: params[:id])
  end

  def words
    @words ||= verse.words.words.order(:position)
  end

  def transliterations_by_word
    @transliterations_by_word ||= WordTransliteration
                                    .where(resource_content_id: resource.id, word_id: words.map(&:id))
                                    .index_by(&:word_id)
  end

  def transliteration_text(word)
    transliterations_by_word[word.id]&.text
  end

  # Progress percentage per verse, two queries for the whole page.
  def verse_progress_map
    verse_ids = verses.map(&:id)
    return {} if verse_ids.empty?

    totals = Word.words.where(verse_id: verse_ids).reorder(nil).group(:verse_id).count
    done = transliterated_words
             .where(words: { verse_id: verse_ids })
             .reorder(nil)
             .group('words.verse_id')
             .count

    verse_ids.index_with do |verse_id|
      total = totals[verse_id].to_i
      total > 0 ? (done[verse_id].to_i * 100.0 / total).floor.clamp(0, 100) : 0
    end
  end

  def pending_suggestions_count
    Draft::WordTranslation
      .where(resource_content_id: resource.id, verse_id: verse.id, imported: false, need_review: true)
      .count
  end

  def page_title
    case action_name
    when 'show'
      "#{resource_name} - #{verse_key}"
    when 'edit'
      "Edit: #{verse_key} - #{resource_name}"
    else
      "Word Transliteration Proofreading"
    end
  end

  def meta_title
    case action_name
    when 'show', 'edit'
      "#{resource_name} - #{verse_key}"
    else
      "Word Transliteration Proofreading Tool"
    end
  end

  def meta_description
    case action_name
    when 'index'
      "Collaborate to improve word by word Quran transliterations. Spot and fix spelling or syllable issues in the transliteration of each word."
    when 'edit'
      "Edit word by word transliteration for Ayah #{verse_key} in #{resource_name}. Submit suggestions for improvements."
    else
      "Review word by word transliteration for Ayah #{verse_key} in #{resource_name}. Verify accuracy and suggest improvements."
    end
  end

  def meta_keywords
    case action_name
    when 'index'
      'Quran word transliteration, word by word transliteration, proofreading, Quran in latin script'
    else
      "Quran word transliteration, #{verse_key}, #{resource_name}, proofreading, transliteration review"
    end
  end

  private

  def transliterated_words
    WordTransliteration
      .joins(:word)
      .where(resource_content_id: resource.id, words: { char_type_id: 1 })
      .where.not(text: [nil, ''])
  end

  def filtered_verses
    list = Verse
    list = list.where(chapter_id: params[:filter_chapter].to_i) if params[:filter_chapter].to_i > 0
    list = list.where(verse_number: params[:verse_number].to_i) if params[:verse_number].to_i > 0

    if params[:filter_missing] == 'true'
      missing = Word.words.where.not(id: transliterated_words.select(:word_id)).select(:verse_id)
      list = list.where(id: missing)
    end

    list.order(verse_index: sort_order)
  end

  def verse_key
    verse&.verse_key || 'Ayah'
  end

  def resource_name
    resource&.name || 'Transliteration'
  end
end
