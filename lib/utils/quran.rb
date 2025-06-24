# frozen_string_literal: true

module Utils
  class Quran
    def self.get_surah_ayah_range(surah)
      surah = surah.to_i
      return [] if surah > 114 || surah < 1

      if 114 == surah
        [FIRST_AYAH[surah - 1], 6236]
      else
        [FIRST_AYAH[surah - 1], FIRST_AYAH[surah] - 1]
      end
    end

    def self.uniq_words_count
      Word.unscoped
          .words
          .group(:text_imlaei)
          .having("COUNT(*) > 0")
          .select('COUNT(*) as count, text_imlaei, unnest((array_agg("id"))[2:])')
    end

    def self.first_ayah_of_surah?(verse_id)
      FIRST_AYAH.include?(verse_id)
    end

    def self.last_ayah_of_surah?(ayah_key_or_id)
      key = if ayah_key_or_id.to_s.include?(':') #ayah key
              ayah_key_or_id
            else
              get_ayah_key_from_id(ayah_key_or_id)
            end

      surah_number, ayah_number = key.split(':').map(&:to_i)

      SURAH_AYAH[surah_number - 1] == ayah_number
    end

    def self.surah_id_from_verse(verse_id)
      surah = nil

      SURAH_AYAH.each_with_index do |surah_ayah, surah_index|
        if verse_id <= surah_ayah
          surah = surah_index + 1
          break
        else
          verse_id -= surah_ayah
        end
      end

      surah
    end

    def self.get_ayah_key_from_id(verse_id)
      return if verse_id.nil?

      surah = nil
      ayah = nil

      SURAH_AYAH.each_with_index do |surah_ayah, surah_index|
        if verse_id <= surah_ayah
          surah = surah_index + 1
          ayah = verse_id

          break
        else
          verse_id -= surah_ayah
        end
      end

      get_ayah_key surah, ayah
    end

    def self.get_ayah_id_from_key(key)
      return if key.blank?

      surah, ayah = key.split(':').map(&:to_i)

      get_ayah_id surah, ayah
    end

    def self.get_ayah_id(surah, ayah)
      abs_ayahs[surah - 1] + ayah
    end

    def self.get_ayah_key(surah, ayah)
      "#{surah}:#{ayah}"
    end

    def self.valid_ayah?(surah, ayah)
      ayah.positive? && SURAH_AYAH[surah - 1] && ayah <= SURAH_AYAH[surah - 1]
    end

    def self.valid_range?(surah, from, to)
      surah = surah.to_i
      from = from.to_i
      to = to.to_i

      if surah >= 1 && surah <= 114
        valid_ayah?(surah, from) && (to.zero? || valid_ayah?(surah, to))
      end
    end

    def self.abs_ayahs
      return @abs_ayahs if @abs_ayahs

      count = 0

      @abs_ayahs = SURAH_AYAH.map do |s|
        e = count
        count += s
        e
      end
    end

    # Ids of first ayah for each surah
    FIRST_AYAH = [
      1, 8, 294, 494, 670, 790, 955, 1161, 1236,
      1365, 1474, 1597, 1708, 1751, 1803, 1902, 2030,
      2141, 2251, 2349, 2484, 2596, 2674, 2792, 2856,
      2933, 3160, 3253, 3341, 3410, 3470, 3504, 3534,
      3607, 3661, 3706, 3789, 3971, 4059, 4134, 4219,
      4273, 4326, 4415, 4474, 4511, 4546, 4584, 4613,
      4631, 4676, 4736, 4785, 4847, 4902, 4980, 5076,
      5105, 5127, 5151, 5164, 5178, 5189, 5200, 5218,
      5230, 5242, 5272, 5324, 5376, 5420, 5448, 5476,
      5496, 5552, 5592, 5623, 5673, 5713, 5759, 5801,
      5830, 5849, 5885, 5910, 5932, 5949, 5968, 5994,
      6024, 6044, 6059, 6080, 6091, 6099, 6107, 6126,
      6131, 6139, 6147, 6158, 6169, 6177, 6180, 6189,
      6194, 6198, 6205, 6208, 6214, 6217, 6222, 6226,
      6231
    ].freeze

    # Count of ayah in each chapter
    SURAH_AYAH = [
      7, 286, 200, 176, 120, 165, 206,
      75, 129, 109, 123, 111, 43, 52,
      99, 128, 111, 110, 98, 135, 112, 78,
      118, 64, 77, 227, 93, 88, 69, 60, 34,
      30, 73, 54, 45, 83, 182, 88, 75, 85, 54,
      53, 89, 59, 37, 35, 38, 29, 18, 45, 60,
      49, 62, 55, 78, 96, 29, 22, 24, 13, 14,
      11, 11, 18, 12, 12, 30, 52, 52, 44, 28,
      28, 20, 56, 40, 31, 50, 40, 46, 42, 29,
      19, 36, 25, 22, 17, 19, 26, 30, 20, 15,
      21, 11, 8, 8, 19, 5, 8, 8, 11, 11, 8,
      3, 9, 5, 4, 7, 3, 6, 3, 5, 4, 5, 6
    ].freeze
  end
end
