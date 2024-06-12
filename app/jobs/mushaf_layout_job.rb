class MushafLayoutJob < ApplicationJob
  def perform(mushaf_id, page_number, words_mapping)
    mushaf = Mushaf.find(mushaf_id)
    mapping = HashWithIndifferentAccess.new(JSON.parse(words_mapping))

    words = save_page_mapping(mapping, mushaf, page_number)
    update_page_stats(mushaf, page_number, words)
  end

  def save_page_mapping(mapping, mushaf, page_number)
    words = mapping['words']
    position_in_line = 1
    position_in_page = 1
    previous_line = nil
    mushaf_words = []

    words.each do |id, line_number|
      next if line_number.blank? || line_number['line_number'].to_i == 0

      word = Word.find(id.to_i).reload
      mushaf_word = MushafWord.where(
        mushaf_id: mushaf.id,
        word_id: word.id
      ).first_or_initialize

      line = line_number['line_number'].to_i

      if !previous_line.nil? && previous_line != line
        position_in_line = 1
      end

      mushaf_word.verse_id = word.verse_id
      mushaf_word.text = word.send(mushaf.text_type_method) if mushaf_word.text.blank?
      mushaf_word.char_type_id = word.char_type_id
      mushaf_word.char_type_name = word.char_type_name
      mushaf_word.line_number = line
      mushaf_word.page_number = page_number
      mushaf_word.position_in_verse = word.position
      mushaf_word.position_in_line = position_in_line
      mushaf_word.position_in_page = position_in_page
      mushaf_word.save
      mushaf_words.push(mushaf_word.id)
      position_in_line += 1
      position_in_page += 1

      previous_line = line
    end

    mushaf_words
  end

  def update_page_stats(mushaf, page_number, words)
    page = MushafPage.where(mushaf_id: mushaf.id, page_number: page_number).first_or_initialize
    # Remove words that are saved for this page but are not part of the page
    page.words.where.not(id: words).delete_all

    first_word = MushafWord.where(page_number: page_number, mushaf_id: mushaf.id).order("position_in_page ASC").first
    last_word = MushafWord.where(page_number: page_number, mushaf_id: mushaf.id).order("position_in_page DESC").first

    verses = Verse.order("verse_index ASC").where("verse_index >= #{first_word.word.verse_id} AND verse_index <= #{last_word.word.verse_id}")
    page.first_verse_id = first_word.word.verse_id
    page.last_verse_id = last_word.word.verse_id
    page.verses_count = verses.size
    page.first_word_id = first_word.word_id
    page.last_word_id = last_word.word_id

    map = {}

    verses.each do |verse|
      if map[verse.chapter_id]
        next
      end

      chapter_verses = verses.where(chapter_id: verse.chapter_id)
      map[verse.chapter_id] = "#{chapter_verses.first.verse_number}-#{chapter_verses.last.verse_number}"
    end

    page.verse_mapping = map
    page.save
  end
end