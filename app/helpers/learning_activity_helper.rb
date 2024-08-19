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
      )
    ]
  end

  def valid_activity?(name)
    ['complete_the_ayah', 'ayah_mastery'].include?(name)
  end

  def generate_ayah_mastery_quiz
    list = Verse.where('words_count < 30').order('random()').includes(:chapter).first(4)
    verse = list.sample

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

  def generate_complete_the_ayah_quiz
    if params[:key]
      verse = Verse.find_by(verse_key: params[:key].strip)
    end

    verse ||= Verse.where('words_count > 6 AND words_count < 40').includes(:words).order("RANDOM()").first
    words = verse.words.select(&:word?)

    words_to_show = words.sample((verse.words_count * 0.6).round)
    remaining_words = words - words_to_show

    {
      verse: verse,
      words: words,
      words_to_show: words_to_show,
      remaining_words: remaining_words.shuffle
    }
  end

  def generate_complete_the_ayah_quiz
    if params[:key]
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