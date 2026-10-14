# frozen_string_literal: true

# A recitation is cut by the ayah numbering of its riwayah (P7.3): the
# numbering_id column, defaulting to the riwayah's default numbering (Kufi
# for Hafs). Its resolver turns the keys the segment tools use into numbered
# ayahs and Kufi verses, and expected_ayahs_count answers "how many ayahs
# should have segments" for the whole Quran or one surah from the numbering
# instead of the Kufi literals.
module RecitationNumbering
  extend ActiveSupport::Concern

  included do
    belongs_to :numbering, class_name: 'AyahNumbering', optional: true
  end

  def numbering_or_default
    numbering || riwayah&.default_numbering || AyahNumbering.kufi
  end

  def kufi_numbering?
    numbering_or_default.kufi?
  end

  def resolver
    @resolver ||= Qiraat::Resolver.new(numbering: numbering_or_default, riwayah: riwayah)
  end

  # ayahs of the whole Quran, or of one chapter, in the recitation's numbering
  def expected_ayahs_count(chapter = nil)
    n = numbering_or_default
    return n.total_ayahs if chapter.nil?

    chapter_id = chapter.is_a?(Chapter) ? chapter.id : chapter.to_i
    n.numbered_ayahs.where(chapter_id: chapter_id, counted: true).count
  end

  # the numbered ayah for a key typed in the recitation's numbering ("2:1")
  def ayah_for_key(key)
    resolver.ayah(key)
  end
end
