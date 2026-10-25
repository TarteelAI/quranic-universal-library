# frozen_string_literal: true

module DraftContent
  class ApproveDraftWordTransliterationJob < ApproveDraftContentJob
    BATCH_SIZE = 1000

    private

    def import_data
      scope = Draft::WordTransliteration.where(resource_content_id: @resource.id, imported: false)
      scope = scope.where(id: @draft_id) if @draft_id

      word_ids = scope.distinct.pluck(:word_id).compact
      existing = WordTransliteration.where(resource_content_id: @resource.id, word_id: word_ids)
                                    .pluck(:word_id, :id).to_h

      # A word can have several suggestions: the latest approved one wins,
      # if none is approved the latest one wins (find_each goes in id order).
      rows = {}
      picked = {}
      imported_ids = []

      scope.find_each(batch_size: BATCH_SIZE) do |draft|
        next if draft.word_id.blank? || draft.draft_text.blank?

        imported_ids << draft.id
        next unless prefer?(draft, picked[draft.word_id])

        picked[draft.word_id] = draft
        rows[draft.word_id] = transliteration_row(draft)
      end

      inserts, updates = rows.values.partition { |row| existing[row[:word_id]].nil? }
      updates = updates.map { |row| row.merge(id: existing[row[:word_id]]) }

      inserts.each_slice(BATCH_SIZE) { |slice| WordTransliteration.insert_all(slice) }
      updates.each_slice(BATCH_SIZE) { |slice| WordTransliteration.upsert_all(slice, unique_by: :id) }

      imported_ids.each_slice(BATCH_SIZE) do |ids|
        Draft::WordTransliteration.where(id: ids).update_all(imported: true)
      end
    end

    # Reviewed drafts (need_review: false) are the approved ones.
    def prefer?(draft, current)
      current.nil? || draft.need_review == false || current.need_review != false
    end

    def transliteration_row(draft)
      {
        word_id: draft.word_id,
        resource_content_id: @resource.id,
        text: draft.draft_text.strip,
        language_id: @resource.language_id,
        language_name: @resource.language_name&.downcase || ''
      }
    end
  end
end
