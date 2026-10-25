# frozen_string_literal: true

module DraftContent
  class ApproveDraftTransliterationJob < ApproveDraftContentJob
    BATCH_SIZE = 1000

    private

    def import_data
      scope = Draft::Transliteration.where(resource_content_id: @resource.id, imported: false)
      scope = scope.where(id: @draft_id) if @draft_id

      verse_ids = scope.distinct.pluck(:verse_id).compact
      verses = Verse.where(id: verse_ids).index_by(&:id)
      existing = Transliteration
       .where(
        resource_content_id: @resource.id,
        verse_id: verse_ids
      ).pluck(:verse_id, :id).to_h

      # A verse can have several suggestions: the latest approved one wins,
      # if none is approved the latest one wins (find_each goes in id order).
      rows = {}
      picked = {}
      imported_ids = []

      scope.find_each(batch_size: BATCH_SIZE) do |draft|
        verse = verses[draft.verse_id]
        next unless verse

        imported_ids << draft.id
        next unless prefer?(draft, picked[verse.id])

        picked[verse.id] = draft
        rows[verse.id] = transliteration_row(draft, verse)
      end

      inserts, updates = rows.values.partition { |row| existing[row[:verse_id]].nil? }
      updates = updates.map { |row| row.merge(id: existing[row[:verse_id]]) }

      inserts.each_slice(BATCH_SIZE) { |slice| Transliteration.insert_all(slice) }
      updates.each_slice(BATCH_SIZE) { |slice| Transliteration.upsert_all(slice, unique_by: :id) }

      imported_ids.each_slice(BATCH_SIZE) do |ids|
        Draft::Transliteration.where(id: ids).update_all(imported: true)
      end
    end

    def prefer?(draft, current)
      current.nil? || draft.need_review == false || current.need_review != false
    end

    def transliteration_row(draft, verse)
      {
        verse_id: verse.id,
        resource_content_id: @resource.id,
        text: draft.draft_text.strip,
        language_id: @resource.language_id,
        language_name: @resource.language_name&.downcase || '',
        verse_key: verse.verse_key,
        chapter_id: verse.chapter_id,
        verse_number: verse.verse_number
      }
    end
  end
end
