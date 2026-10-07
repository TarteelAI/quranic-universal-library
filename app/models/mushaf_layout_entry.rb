# frozen_string_literal: true

# What the layout editor lists for one page (P5.5): one group per ayah of the
# mushaf's numbering, each holding the printed words and the ayah-end marker,
# keyed the way MushafLayoutJob reads the form back.
#
# A Kufi mushaf (every layout before P5.3, and Hafs/Shu'bah) lists the Kufi
# verses of the page with their words rows, end marker included, exactly as
# the editor always has. A mushaf on another numbering lists its numbered
# ayahs: the words the edition reads, then the marker row, which is a words
# row where the ayah ends on a Kufi verse end and otherwise the mushaf_words
# row itself, keyed "mw<id>" because it has no words row behind it.
class MushafLayoutEntry
  Ayah = Struct.new(:id, :verse_key, :entries)
  Entry = Struct.new(:key, :word_id, :text, :location, :line_number)

  def self.for_page(mushaf, page, mushaf_words)
    new(mushaf, page, mushaf_words).ayahs
  end

  def initialize(mushaf, page, mushaf_words)
    @mushaf = mushaf
    @page = page
    @mushaf_words = mushaf_words.to_a
    @line_by_word = @mushaf_words.each_with_object({}) { |w, h| h[w.word_id] ||= w.line_number if w.word_id }
  end

  def ayahs
    numbered? ? numbered_ayahs : kufi_verses
  end

  private

  def numbered?
    @mushaf.numbering_id.present? && !@mushaf.numbering.kufi? && @page.first_ayah_id.present? && @page.last_ayah_id.present?
  end

  def kufi_verses
    return [] unless @page.first_verse && @page.last_verse

    Verse.eager_load(:words).order('verses.verse_index asc, words.position asc')
         .where('verse_index >= ? AND verse_index <= ?', @page.first_verse.verse_index, @page.last_verse.verse_index)
         .map do |verse|
      Ayah.new(verse.id, verse.verse_key, verse.words.sort_by(&:position).map { |w| word_entry(w) })
    end
  end

  def numbered_ayahs
    markers = @mushaf_words.select { |w| w.char_type_name == 'end' }.group_by(&:ayah_id)
    NumberedAyah.where(numbering_id: @mushaf.numbering_id, id: @page.first_ayah_id..@page.last_ayah_id).order(:id).map do |ayah|
      entries = ayah.words.map { |w| word_entry(w) }
      (markers[ayah.id] || []).each do |m|
        entries << if m.word_id
                     word_entry(m.word)
                   else
                     Entry.new("mw#{m.id}", nil, m.text, "#{ayah.ayah_key} end", m.line_number)
                   end
      end
      Ayah.new(ayah.id, ayah.ayah_key, entries)
    end
  end

  def word_entry(word)
    Entry.new(word.id, word.id, word.text_for_mushaf(@mushaf.id), word.location, @line_by_word[word.id])
  end
end
