module LearningActivityHelper
  REGEXP_STRIP_AYAH_NUMBERS = /[١٢٣٤٥٦٧٨٩٠۩ۤ۞]+/

  def learning_activities
    [
      ToolCard.new(
        title: 'Complete the Ayah',
        description: 'Test your knowledge by filling in the missing words of Quranic verses. Drag and drop the correct words to complete each Ayah and enhance your memorization skills.',
        icon: 'list.svg',
        url: learning_activity_path('complete_the_ayah'),
        tags: ['Fill in the Blank', 'Ayah Challenge']
      ),
      ToolCard.new(
        title: 'Ayah Mastery',
        description: 'Sharpen your Quranic knowledge by identifying the correct Ayah from multiple choices. Test your memory and strive to become an Ayah Master!',
        icon: 'list.svg',
        url: learning_activity_path('ayah_mastery'),
        tags: ['Quran Learning', 'Hafiz Training', 'Ayah Guessing']
      ),
      ToolCard.new(
        title: 'Word Match',
        description: 'Match Arabic words with their correct English/Urdu translations by dragging or tapping.',
        icon: 'list.svg',
        url: learning_activity_path('word_match'),
        tags: ['Vocabulary', 'Word Matching']
      )
    ]
  end

  def valid_activity?(name)
    ['complete_the_ayah', 'ayah_mastery', 'word_match'].include?(name)
  end

  def generate_ayah_mastery_quiz
    # If specific ayah is filtered, use it as the correct answer
    if @filtered_ayah
      verse = @filtered_ayah
      # Get 3 other similar verses for options
      list = Verse.where('words_count < 30')
                  .where.not(id: verse.id)
                  .includes(:chapter)
                  .order('random()')
                  .first(3)
      list << verse
    else
      list = Verse.where('words_count < 30').order('random()').includes(:chapter).first(4)
      verse = list.sample
    end

    options = list.map do |v|
      {
        id: v.id,
        name: "Surah #{v.chapter.name_simple} : #{v.verse_number}",
        correct: v.id == verse.id
      }
    end

    {
      verse: verse,
      text: verse.text_qpc_hafs.gsub(REGEXP_STRIP_AYAH_NUMBERS, ''),
      options: options.shuffle
    }
  end

  # Build data for Word Match activity: a list of arabic words and their translations
  # Prefer English; if not available, fallback to Urdu
  def generate_word_match_quiz
    if @filtered_ayah
      # Use words only from the specified ayah
      words = Word.where(verse_id: @filtered_ayah.id, char_type_id: 1)
                  .includes(:en_translation, :ur_translation)

      # If the ayah doesn't have enough words or translations, fallback to random
      if words.count < 3
        words = Word.where(char_type_id: 1).includes(:en_translation, :ur_translation).order('RANDOM()').limit(5)
      else
        words = words.limit(words.count > 5 ? 5 : words.count)
      end
    else
      # Fetch random verses with moderate length to avoid very small stopwords-only sets
      verses = Verse.where('words_count BETWEEN 4 AND 12').order('RANDOM()').limit(5)
      words = Word.where(verse_id: verses.map(&:id), char_type_id: 1).includes(:en_translation, :ur_translation).sample(5)

      # Fallback in case previous query is sparse
      if words.size < 5
        words = Word.where(char_type_id: 1).includes(:en_translation, :ur_translation).order('RANDOM()').limit(5)
      end
    end

    pairs = words.map do |w|
      translation = w.en_translation&.text.presence || w.ur_translation&.text.presence || w.word_translation&.text.presence || ''
      {
        id: w.id,
        arabic: w.text_qpc_hafs,
        translation: translation
      }
    end

    # Ensure we only include pairs with a translation
    pairs = pairs.select { |p| p[:translation].present? }

    {
      pairs: pairs,
      left_words: pairs.map { |p| { id: p[:id], text: p[:arabic] } },
      right_translations: pairs.map { |p| { id: p[:id], text: p[:translation] } }.shuffle
    }
  end



  def generate_complete_the_ayah_quiz
    # Use filtered ayah if available, otherwise use params[:key] or random verse
    if @filtered_ayah
      verse = @filtered_ayah
      # If filtered ayah is too short, fallback to random verse
      if verse.words_count < 4
        verse = Verse.where('words_count > 6 AND words_count < 40').includes(:words).order("RANDOM()").first
      end
    elsif params[:key]
      verse = Verse.find_by(verse_key: params[:key].strip)
    end

    verse ||= Verse.where('words_count > 6 AND words_count < 40').includes(:words).order("RANDOM()").first
    words = verse.words.select(&:word?)

    total_words = words.size
    blanks_to_create = (total_words * 0.4).round

    # Shuffle indices for randomness
    indices = (0...total_words).to_a.shuffle
    words_to_show = Array.new(total_words, true)  # True means the word is shown
    remaining_words = []
    consecutive_blanks = 0

    indices.each do |index|
      if blanks_to_create > 0 && can_blank?(index, total_words, consecutive_blanks, words_to_show)
        words_to_show[index] = false
        remaining_words << words[index]
        blanks_to_create -= 1
        consecutive_blanks += 1
      else
        consecutive_blanks = 0
      end
    end

    words_to_show_final = words.each_with_index.select { |_, index| words_to_show[index] }.map(&:first)

    {
      verse: verse,
      words: words,
      words_to_show: words_to_show_final,
      remaining_words: remaining_words.shuffle
    }
  end

  private

  def can_blank?(index, total_words, consecutive_blanks, words_to_show)
    return false if consecutive_blanks >= 2

    # Check the previous and next word
    prev_blank = index > 0 ? !words_to_show[index - 1] : false
    next_blank = index < total_words - 1 ? !words_to_show[index + 1] : false

    !(prev_blank && next_blank) # Prevent blanking if both adjacent words are blank
  end
end