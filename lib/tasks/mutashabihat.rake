namespace :mutashabihat do
  desc 'Audit Morphology::Phrase + Morphology::PhraseVerse for ranges that fall outside their verse boundaries'
  task audit_ranges: :environment do
    puts 'Scanning Morphology::Phrase source ranges...'
    bad_phrases = []
    Morphology::Phrase.includes(:source_verse).find_each do |phrase|
      verse = phrase.source_verse
      next unless verse && phrase.word_position_from && phrase.word_position_to

      max = verse.words_count || verse.words.count
      reasons = []
      reasons << "from > to (#{phrase.word_position_from} > #{phrase.word_position_to})" if phrase.word_position_from > phrase.word_position_to
      reasons << "to > words_count (#{phrase.word_position_to} > #{max})" if phrase.word_position_to > max

      next if reasons.empty?

      bad_phrases << {
        id: phrase.id,
        verse_key: verse.verse_key,
        words_count: max,
        range: [phrase.word_position_from, phrase.word_position_to],
        approved: phrase.approved,
        reasons: reasons
      }
    end

    if bad_phrases.empty?
      puts '  no invalid phrase source ranges'
    else
      puts "  #{bad_phrases.size} invalid phrase source range(s):"
      bad_phrases.each do |row|
        puts "    phrase ##{row[:id]} approved=#{row[:approved]} #{row[:verse_key]} (#{row[:words_count]} words) range=#{row[:range].inspect} — #{row[:reasons].join(', ')}"
      end
    end

    puts ''
    puts 'Scanning Morphology::PhraseVerse ranges...'
    bad_verses = []
    Morphology::PhraseVerse.includes(:verse).find_each do |phrase_verse|
      verse = phrase_verse.verse
      next unless verse && phrase_verse.word_position_from && phrase_verse.word_position_to

      max = verse.words_count || verse.words.count
      reasons = []
      reasons << "from > to (#{phrase_verse.word_position_from} > #{phrase_verse.word_position_to})" if phrase_verse.word_position_from > phrase_verse.word_position_to
      reasons << "to > words_count (#{phrase_verse.word_position_to} > #{max})" if phrase_verse.word_position_to > max

      next if reasons.empty?

      bad_verses << {
        id: phrase_verse.id,
        phrase_id: phrase_verse.phrase_id,
        verse_key: verse.verse_key,
        words_count: max,
        range: [phrase_verse.word_position_from, phrase_verse.word_position_to],
        approved: phrase_verse.approved,
        reasons: reasons
      }
    end

    if bad_verses.empty?
      puts '  no invalid phrase_verse ranges'
    else
      puts "  #{bad_verses.size} invalid phrase_verse range(s):"
      bad_verses.each do |row|
        puts "    phrase_verse ##{row[:id]} phrase=#{row[:phrase_id]} approved=#{row[:approved]} #{row[:verse_key]} (#{row[:words_count]} words) range=#{row[:range].inspect} — #{row[:reasons].join(', ')}"
      end
    end

    total = bad_phrases.size + bad_verses.size
    if total.positive?
      puts ''
      puts "Found #{total} invalid range(s)."
      exit 1
    end
  end
end
