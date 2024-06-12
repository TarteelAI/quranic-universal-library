class WildcardMatcher
  ALL_VERSES =  Verse.all

  def search(sequence, verses = nil)
    find_verses_by_word_sequence(sequence.remove_dialectic(replace_hamza: true), verses || ALL_VERSES)
  end

  def match_sequence_with_wildcard(pattern, text)
    pattern_parts = pattern.split('*').map { |part| Regexp.escape(part.strip) }
    regex_pattern = pattern_parts.join('.*?')
    regex = Regexp.new("\\b#{regex_pattern}\\b", Regexp::IGNORECASE)
    match_data = text.match(regex)

    if match_data
      start_index = match_data.begin(0)
      end_index = match_data.end(0) - 1
      { matched: true, start_index: start_index, end_index: end_index }
    else
      { matched: false, start_index: nil, end_index: nil }
    end
  end

  def find_verses_by_word_sequence(sequence, verses)
    matching_verses = []
    attr_to_search = [
      'text_imlaei_simple',
      'text_uthmani',
      'text_indopak',
      'text_imlaei',
      'text_uthmani_simple',
      'text_qpc_hafs',
      'text_qpc_nastaleeq'
    ]

    verses.each do |verse|
      verse_text = verse.text_imlaei_simple
      match_data = match_sequence_with_wildcard(sequence, verse_text)
      match_data |= match_sequence_with_wildcard(sequence, verse_text)

      if match_data[:matched]
        matching_verses << { verse: verse, start_index: match_data[:start_index], end_index: match_data[:end_index] }
      end
    end

    matching_verses
  end
end