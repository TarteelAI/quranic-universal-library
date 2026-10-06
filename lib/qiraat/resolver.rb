# frozen_string_literal: true

module Qiraat
  # The one place a reference in any numbering is turned into rows (P4.4).
  #
  #   r = Qiraat::Resolver.new(numbering: AyahNumbering.find_by!(slug: 'madani-last'))
  #   r.ayah(2, 1)                 # => NumberedAyah 2:1 (merges Kufi 2:1-2:2)
  #   r.from_kufi(Verse 1:7)       # => [NumberedAyah 1:6, NumberedAyah 1:7]   (split: always an array)
  #   r.to_kufi(ayah)              # => [Verse 2:1, Verse 2:2]                 (merged: the whole range)
  #   r.word_range(ayah)           # => words of the ayah in order (all riwayat; filter per script)
  #   r.text(script, ayah)         # => the ayah text in that script
  #
  # Every lookup is one or two indexed reads; results that can be several
  # rows are always arrays, so callers render or join over all of them and
  # never show only the first half of a split or a merge.
  class Resolver
    attr_reader :numbering

    def self.for(riwayah_or_slug)
      riwayah = riwayah_or_slug.is_a?(Riwayah) ? riwayah_or_slug : Riwayah.find_by!(slug: riwayah_or_slug)
      new(numbering: riwayah.default_numbering || AyahNumbering.kufi)
    end

    def self.kufi
      new(numbering: AyahNumbering.kufi)
    end

    def initialize(numbering:)
      @numbering = numbering
    end

    def kufi?
      numbering.kufi?
    end

    # The ayah with this key in the numbering ("2:1" or chapter + number); nil when absent.
    def ayah(chapter_or_key, number = nil)
      chapter = chapter_or_key
      chapter, number = chapter_or_key.to_s.split(':').map(&:to_i) if number.nil?
      chapter_id = chapter.is_a?(Chapter) ? chapter.id : Chapter.find_by(chapter_number: chapter.to_i)&.id
      return nil unless chapter_id

      NumberedAyah.find_by(numbering_id: numbering.id, chapter_id: chapter_id, ayah_number: number.to_i)
    end

    # Kufi verse (record, id or key) -> the ayahs of this numbering that carry its words.
    # One for same/shifted/merged/unnumbered, two for a split. Empty when unmapped.
    def from_kufi(verse)
      verse = resolve_verse(verse)
      return [] unless verse

      mapping = AyahMapping.find_by(numbering_id: numbering.id, verse_id: verse.id)
      return [] unless mapping

      mapping.ayahs
    end

    # Numbered ayah -> every Kufi verse it covers, in order (two for a merge).
    def to_kufi(ayah)
      ayah.kufi_verses.to_a
    end

    # How a Kufi verse relates to this numbering: same | shifted | merged | split | unnumbered | nil.
    def relation(verse)
      verse = resolve_verse(verse)
      verse && AyahMapping.find_by(numbering_id: numbering.id, verse_id: verse.id)&.relation
    end

    # The shared words of the ayah in order (all riwayat; filter by script with Word#text_for).
    def word_range(ayah)
      ayah.words.to_a
    end

    # The ayah text in a script: the ayah_texts cache or the joined word forms.
    def text(script, ayah)
      ayah.text_for(script)
    end

    private

    def resolve_verse(verse)
      case verse
      when Verse then verse
      when Integer then Verse.find_by(id: verse)
      when String then Verse.find_by(verse_key: verse)
      end
    end
  end
end
