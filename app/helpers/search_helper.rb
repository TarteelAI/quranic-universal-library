# frozen_string_literal: true

module SearchHelper
  def format_verse_result(verse)
    {
      'verse_key' => verse.verse_key,
      'chapter_id' => verse.chapter_id,
      'verse_number' => verse.verse_number,
      'text_uthmani' => verse.text_uthmani,
      'text_qpc_hafs' => verse.text_qpc_hafs,
      'words' => format_verse_words(verse),
      'translations' => verse.translations.limit(2).map do |translation|
        {
          'text' => translation.text,
          'language_name' => translation.language&.name,
          'resource_name' => translation.resource_name
        }
      end,
      'semantic_context' => extract_semantic_context(verse)
    }
  end

  def format_word_result(word)
    {
      'verse_key' => word.verse_key,
      'chapter_id' => word.chapter_id,
      'position' => word.position,
      'text_uthmani' => word.text_uthmani,
      'text' => word.text_uthmani,
      'root_name' => word.root&.value,
      'lemma_name' => word.lemma&.text_clean,
      'morphology' => word.morphology_word_segments.map do |segment|
        {
          'part_of_speech' => segment.part_of_speech_key,
          'pos_tags' => segment.pos_tags,
          'grammar_role' => segment.grammar_role,
          'verb_form' => segment.verb_form
        }
      end,
      'word_translations' => word.word_translations.limit(3).map do |translation|
        {
          'text' => translation.text,
          'language_name' => translation.language&.name
        }
      end
    }
  end

  def format_verse_words(verse)
    words = verse.text_uthmani.split(' ')
    words.map do |word|
      {
        'text' => word,
        'highlight' => false # Would be true if this word matches the search
      }
    end
  end

  def extract_semantic_context(verse)
    {
      'topics' => verse.words.joins(:topic).limit(5).pluck('topics.name').compact,
      'roots' => verse.words.joins(:root).limit(5).pluck('roots.value').compact,
      'word_count' => verse.words_count
    }
  end

  def highlight_search_terms(text, terms)
    return text if terms.blank?
    
    highlighted = text
    Array(terms).each do |term|
      highlighted = highlighted.gsub(/(#{Regexp.escape(term)})/i, '<mark>\1</mark>')
    end
    highlighted.html_safe
  end

  def search_result_snippet(text, max_length = 200)
    return text if text.length <= max_length
    
    # Try to find a good breaking point
    snippet = text.truncate(max_length, separator: ' ')
    "#{snippet}..."
  end

  def format_morphology_tag(tag)
    case tag
    when 'N' then 'Noun'
    when 'V' then 'Verb'
    when 'P' then 'Preposition'
    when 'ADJ' then 'Adjective'
    when 'ADV' then 'Adverb'
    when 'PRON' then 'Pronoun'
    when 'DET' then 'Determiner'
    when 'CONJ' then 'Conjunction'
    else tag
    end
  end

  def verse_navigation_context(verse)
    {
      chapter_name: verse.chapter&.name_simple,
      chapter_id: verse.chapter_id,
      verse_number: verse.verse_number,
      juz_number: verse.juz_number,
      hizb_number: verse.hizb_number,
      page_number: verse.page_number
    }
  end

  def search_filter_summary(params)
    filters = []
    
    filters << "Chapter #{params[:chapter_id]}" if params[:chapter_id].present?
    filters << "Juz #{params[:juz_number]}" if params[:juz_number].present?
    filters << "Language: #{Language.find(params[:language_id]).name}" if params[:language_id].present?
    filters << "Part of Speech: #{params[:part_of_speech]}" if params[:part_of_speech].present?
    filters << "Root: #{params[:root_name]}" if params[:root_name].present?
    
    filters.join(', ')
  end
end