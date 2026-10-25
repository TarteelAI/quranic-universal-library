# frozen_string_literal: true

# What happens to the other tafsirs of a resource when one tafsir gets a new
# ayah range. Groups of a tafsir never overlap, so ayahs this tafsir takes are
# removed from the groups that had them:
#
#   - a group that loses some ayahs is shortened (22-25 takes 25 from 25-27 → 26-27)
#   - a group that loses all its ayahs is archived
#
# Ayahs this tafsir lets go of are left without tafsir, until someone adds
# them to another group or writes their own tafsir.
#
#   change = Draft::TafsirRangeChange.new(resource_content_id: 169, tafsir: tafsir, start_verse_id: 10, end_verse_id: 12)
#   change.valid?  # false when the range would split another group in two
#   change.apply!  # when the draft is approved
module Draft
  class TafsirRangeChange
    # A group losing ayahs. result is :shortened or :archived
    Effect = Struct.new(:tafsir, :taken_ids, :new_start_id, :new_end_id, keyword_init: true) do
      def result
        new_start_id ? :shortened : :archived
      end
    end

    attr_reader :resource_content_id, :tafsir, :start_verse_id, :end_verse_id

    # tafsir is nil when adding tafsir for ayahs that have none
    def initialize(resource_content_id:, start_verse_id:, end_verse_id:, tafsir: nil)
      @resource_content_id = resource_content_id
      @tafsir = tafsir&.persisted? ? tafsir : nil
      @start_verse_id = start_verse_id.to_i
      @end_verse_id = end_verse_id.to_i
    end

    def errors
      @errors ||= begin
        list = []
        if start_verse_id <= 0 || end_verse_id <= 0
          list << 'Select the first and last ayah'
        elsif start_verse_id > end_verse_id
          list << 'The first ayah must come before the last ayah'
        else
          splits = overlapping.select { |t| t.start_verse_id < start_verse_id && t.end_verse_id > end_verse_id }
          splits.each do |t|
            list << "#{verse_key(start_verse_id)} - #{verse_key(end_verse_id)} is in the middle of the tafsir for #{t.group_verse_key_from} - #{t.group_verse_key_to}. Edit that tafsir instead, a range can't split another tafsir in two."
          end
        end
        list
      end
    end

    def valid?
      errors.empty?
    end

    def range_ids
      (start_verse_id..end_verse_id).to_a
    end

    def old_range_ids
      tafsir ? (tafsir.start_verse_id..tafsir.end_verse_id).to_a : []
    end

    def changed?
      range_ids != old_range_ids
    end

    def added_ids
      range_ids - old_range_ids
    end

    # Ayahs this tafsir lets go of, they'll have no tafsir
    def released_ids
      old_range_ids - range_ids
    end

    # Other groups that lose ayahs to this range
    def effects
      @effects ||= overlapping.map do |other|
        remaining = (other.start_verse_id..other.end_verse_id).to_a - range_ids

        Effect.new(
          tafsir: other,
          taken_ids: (other.start_verse_id..other.end_verse_id).to_a & range_ids,
          new_start_id: remaining.first,
          new_end_id: remaining.last
        )
      end
    end

    # Ayahs added to this range that had no tafsir before
    def uncovered_added_ids
      added_ids - effects.flat_map(&:taken_ids)
    end

    # Ayah ids to draw, the current and the new range together
    def window_ids
      ids = range_ids + old_range_ids
      ids.empty? ? [] : (ids.min..ids.max).to_a
    end

    def verse_key(id)
      verse_keys[id] ||= Verse.where(id: id).pick(:verse_key)
    end

    def range_label(ids)
      return '' if ids.empty?

      ids.size == 1 ? verse_key(ids.first) : "#{verse_key(ids.first)} - #{verse_key(ids.last)}"
    end

    def apply!
      raise ArgumentError, errors.to_sentence unless valid?

      effects.each do |effect|
        other = effect.tafsir

        if effect.result == :archived
          other.update!(archived: true)
        else
          other.start_verse_id = effect.new_start_id
          other.end_verse_id = effect.new_end_id
          other.group_verses_count = effect.new_end_id - effect.new_start_id + 1
          move_primary_verse(other, effect.new_start_id) unless other.verse_id.between?(effect.new_start_id, effect.new_end_id)
          other.save!(validate: false)
        end
      end
    end

    private

    def live_tafsirs
      ::Tafsir.where(resource_content_id: resource_content_id, archived: false)
    end

    def overlapping
      return [] if start_verse_id > end_verse_id

      @overlapping ||= begin
        list = live_tafsirs.where('start_verse_id <= ? AND end_verse_id >= ?', end_verse_id, start_verse_id)
        list = list.where.not(id: tafsir.id) if tafsir
        list.order(:start_verse_id).to_a
      end
    end

    def move_primary_verse(tafsir, verse_id)
      verse = Verse.find(verse_id)

      tafsir.verse_id = verse.id
      tafsir.group_tafsir_id = verse.id
      tafsir.verse_key = verse.verse_key
      tafsir.chapter_id = verse.chapter_id
      tafsir.verse_number = verse.verse_number
      tafsir.juz_number = verse.juz_number
      tafsir.hizb_number = verse.hizb_number
      tafsir.rub_el_hizb_number = verse.rub_el_hizb_number
      tafsir.ruku_number = verse.ruku_number
      tafsir.surah_ruku_number = verse.surah_ruku_number
      tafsir.manzil_number = verse.manzil_number
      tafsir.page_number = verse.page_number
    end

    def verse_keys
      @verse_keys ||= valid_range? ? Verse.where(id: window_ids).pluck(:id, :verse_key).to_h : {}
    end

    def valid_range?
      start_verse_id.positive? && end_verse_id >= start_verse_id
    end
  end
end
