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
      mushaf_word.ayah_id ||= AyahMapping.find_by(numbering_id: mushaf.numbering_id, verse_id: word.verse_id)&.ayah_id if mushaf.numbering_id
      mushaf_word.text = (mushaf.script ? word.text_for(mushaf.script) : word.send(mushaf.text_type_method)) if mushaf_word.text.blank?
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

    # mushaf_words carries verse_id and ayah_id itself (P5.2); one verse_mapping shape everywhere
    page.first_verse_id = first_word.verse_id
    page.last_verse_id = last_word.verse_id
    page.first_word_id = first_word.word_id
    page.last_word_id = last_word.word_id
    page.first_ayah_id = first_word.ayah_id
    page.last_ayah_id = last_word.ayah_id
    page.verses_count = Verse.where(verse_index: first_word.verse_id..last_word.verse_id).count
    page.verse_mapping = MushafPage.build_verse_mapping(first_word.verse_id, last_word.verse_id)
    page.save
  end
end