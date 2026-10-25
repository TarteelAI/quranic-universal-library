module Mutashabihat
  # Merges duplicate phrases into one and deletes the duplicates.
  #
  # Each ayah row of a duplicate moves to the kept phrase. When the kept
  # phrase already has the ayah with about the same words, the row with the
  # stronger review decision wins (see DECISION_RANK) and the other is dropped.
  class PhraseMerge
    # Higher wins: a reviewer's decision beats an automatic one
    DECISION_RANK = {
      ['new', true] => 4,
      ['new', false] => 3,
      ['remove', false] => 2,
      ['remove', true] => 2,
      [nil, true] => 1,
      [nil, false] => 0
    }.freeze

    attr_reader :keep, :duplicates, :moved, :combined

    def initialize(keep, duplicates)
      @keep = keep
      @duplicates = duplicates.reject { |p| p.id == keep.id }
      @moved = 0
      @combined = 0
    end

    def run
      Morphology::Phrase.transaction do
        sources = duplicates.select { |d| d.source_verse_id && d.word_position_from }

        duplicates.each do |duplicate|
          duplicate.phrase_verses.each { |row| merge_row(row) }

          keep.approved ||= duplicate.approved?
          keep.review_status = 'new' if duplicate.reviewed?
          duplicate.reload.destroy!
        end

        fill_source_range(sources)
        refresh_text
        keep.save!(validate: false)
        keep.update_verses_stats
      end

      self
    end

    protected

    def merge_row(row)
      same = keep.phrase_verses.where(verse_id: row.verse_id).detect do |kept|
        kept.word_position_from && row.word_position_from &&
          Suggestion.overlap([kept.word_position_from, kept.word_position_to], [row.word_position_from, row.word_position_to]) >= DuplicatePhrases::MIN_OVERLAP
      end

      if same
        if rank(row) > rank(same)
          same.update_columns(row.attributes.slice('approved', 'review_status', 'word_position_from', 'word_position_to',
                                                   'matched_words_count', 'missing_word_positions'))
        end
        row.delete
        @combined += 1
      else
        row.update_columns(phrase_id: keep.id)
        @moved += 1
      end
    end

    # Older phrases have a source ayah but no word range. Take it from the
    # kept phrase's row in that ayah, or from a merged duplicate.
    def fill_source_range(sources)
      return if keep.source_verse_id && keep.word_position_from && keep.word_position_to

      row = keep.phrase_verses.where(verse_id: keep.source_verse_id).where.not(word_position_from: nil).first if keep.source_verse_id
      if row
        keep.word_position_from = row.word_position_from
        keep.word_position_to = row.word_position_to
      elsif (source = sources.first)
        keep.source_verse_id = source.source_verse_id
        keep.word_position_from = source.word_position_from
        keep.word_position_to = source.word_position_to
      end
    end

    # Some saved texts don't match their range (an ayah number, a missing
    # word), so the kept phrase gets the text of its source range again
    def refresh_text
      return unless keep.source_verse_id && keep.word_position_from && keep.word_position_to

      text = Word.where(verse_id: keep.source_verse_id, position: keep.word_position_from..keep.word_position_to, char_type_name: 'word')
                 .order(:position).pluck(:text_qpc_hafs).join(' ')
      return if text.blank?

      keep.text_qpc_hafs = text
      keep.text_qpc_hafs_simple = text.remove_diacritics
    end

    def rank(row)
      DECISION_RANK.fetch([row.review_status.presence, !!row.approved], 0)
    end
  end
end
