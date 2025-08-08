# app/jobs/draft_content/approve_draft_uloom_content_job.rb
module DraftContent
  class ApproveDraftUloomContentJob < ApproveDraftContentJob
    private

    def import_data
      if @draft_id
        import_single(Draft::Content.find(@draft_id))
      else
        Draft::Content
          .where(resource_content_id: @resource.id, imported: false)
          .find_each(batch_size: 500) { |draft| import_single(draft) }
      end
    end

    def import_single(draft)
      # 1) Determine cardinality_type
      card = if draft.word_id
               'word'
             elsif draft.verse_id
               'verse'
             else
               'chapter'
             end

      # 2) Split raw location into from/to
      from_raw, to_raw = draft.location.to_s.split('-', 2).map(&:strip)
      to_raw ||= from_raw

      # 3) Normalize each side
      from_loc = normalize_loc(from_raw, draft, card)
      to_loc   = normalize_loc(to_raw,   draft, card)

      # 4) Build attribute hash
      attrs = {
        resource_content_id: @resource.id,
        chapter_id:          draft.chapter_id,
        cardinality_type:    card,
        text:                draft.draft_text.to_s.strip,
        meta_data:           draft.meta_data || {}
      }
      attrs[:verse_id] = draft.verse_id if draft.verse_id
      attrs[:word_id]  = draft.word_id  if draft.word_id

      # 5) Finalize location fields
      attrs[:location]        = from_loc
      # always show “from – to”, even if identical
      attrs[:location_range]  = "#{from_loc} - #{to_loc}"

      # 6) Upsert the UloomContent record
      record = UloomContent.find_or_initialize_by(
        resource_content_id: attrs[:resource_content_id],
        chapter_id:          attrs[:chapter_id],
        verse_id:            attrs[:verse_id],
        word_id:             attrs[:word_id]
      )
      record.assign_attributes(attrs)
      record.save!(validate: false)

      # 7) Mark the draft as imported
      draft.update_column(:imported, true)
    end

    # Expand a raw segment (e.g. "1", "1:4", or "3") into the full loc string
    def normalize_loc(raw, draft, card)
      parts = raw.split(':').map(&:to_i)

      case card
      when 'word'
        # want "chapter:verse:word"
        if parts.length == 1
          "#{draft.chapter_id}:#{draft.verse_id}:#{parts[0]}"
        elsif parts.length == 2
          "#{draft.chapter_id}:#{parts[0]}:#{parts[1]}"
        else
          raw
        end

      when 'verse'
        # want "chapter:verse"
        if parts.length == 1
          "#{draft.chapter_id}:#{parts[0]}"
        else
          raw
        end

      else # chapter
        # always just the chapter
        draft.chapter_id.to_s
      end
    end
  end
end
