# frozen_string_literal: true

module DraftContent
  class ApproveDraftTafsirJob < ApproveDraftContentJob
    BATCH_SIZE = 500

    private

    def import_from_legacy_table
      verses = Verse.all.index_by(&:id)
      imported_ids = []
      imported_ayahs = {}
      draft_ids = []

      Draft::Tafsir.where(resource_content_id: @resource.id).find_each(batch_size: BATCH_SIZE) do |draft|
        next if draft.draft_text.blank? || imported_ayahs[draft.verse_key]

        verse = verses[draft.verse_id]
        next unless verse

        tafsir = Tafsir.for_verse(verse, @resource) || Tafsir.new
        set_tafsir_attributes(tafsir, draft, verse, verses)
        tafsir.save(validate: false)

        imported_ids << tafsir.id
        imported_ayahs[verse.verse_key] = true
        group_ayah_keys(draft.start_verse_id, draft.end_verse_id, verses).each { |key| imported_ayahs[key] = true }

        draft_ids << draft.id
        if draft_ids.size >= BATCH_SIZE
          Draft::Tafsir.where(id: draft_ids).update_all(imported: true)
          draft_ids = []
        end
      end

      Draft::Tafsir.where(id: draft_ids).update_all(imported: true) if draft_ids.any?
      archive_old_tafsirs(imported_ids)
    end

    def import_from_draft_content
      verses = Verse.all.index_by(&:id)
      scope =
        if @draft_id
          Draft::Content.where(id: @draft_id)
        else
          Draft::Content.where(resource_content_id: @resource.id, imported: false)
        end

      draft_ids = []
      scope.find_each(batch_size: BATCH_SIZE) do |draft|
        import_single_tafsir(draft, verses)

        draft_ids << draft.id
        if draft_ids.size >= BATCH_SIZE
          Draft::Content.where(id: draft_ids).update_all(imported: true)
          draft_ids = []
        end
      end

      Draft::Content.where(id: draft_ids).update_all(imported: true) if draft_ids.any?
    end

    def import_single_tafsir(draft, verses)
      start_loc, end_loc = draft.location.to_s.split('-')
      chapter_str, start_str = start_loc.split(':')
      end_str = end_loc || start_str
      start_num = start_str.to_i
      end_num = end_str.to_i

      verse_keys = (start_num..end_num).map { |v| "#{chapter_str}:#{v}" }
      end_verse_id = draft.verse_id + (end_num - start_num)

      tafsir = Tafsir.find_or_initialize_by(
        resource_content_id: @resource.id,
        verse_id: draft.verse_id
      )

      tafsir.assign_attributes(
        text: draft.draft_text.to_s.strip,
        language_id: @resource.language_id,
        language_name: @resource.language_name&.downcase || '',
        resource_name: @resource.name,
        verse_key: verse_keys.first,
        group_tafsir_id: draft.verse_id,
        group_verses_count: verse_keys.size
      )
      assign_group_range(tafsir, draft.verse_id, end_verse_id, verses)
      tafsir.save!(validate: false)
    end

    def set_tafsir_attributes(tafsir, draft, verse, verses)
      tafsir.assign_attributes(
        resource_content_id: @resource.id,
        text: draft.draft_text.strip,
        language_id: @resource.language_id,
        language_name: @resource.language_name&.downcase || '',
        resource_name: @resource.name,
        verse_id: verse.id,
        verse_key: verse.verse_key,
        chapter_id: verse.chapter_id,
        verse_number: verse.verse_number,
        juz_number: verse.juz_number,
        hizb_number: verse.hizb_number,
        rub_el_hizb_number: verse.rub_el_hizb_number,
        ruku_number: verse.ruku_number,
        surah_ruku_number: verse.surah_ruku_number,
        manzil_number: verse.manzil_number,
        page_number: verse.page_number,
        group_tafsir_id: draft.group_tafsir_id,
        archived: false
      )
      assign_group_range(tafsir, draft.start_verse_id, draft.end_verse_id, verses)
      tafsir.group_verses_count = group_ayah_keys(draft.start_verse_id, draft.end_verse_id, verses).size
    end

    def assign_group_range(tafsir, start_id, end_id, verses)
      tafsir[:start_verse_id] = start_id
      tafsir[:end_verse_id] = end_id
      tafsir.group_verse_key_from = verses[start_id]&.verse_key
      tafsir.group_verse_key_to = verses[end_id]&.verse_key
    end

    def group_ayah_keys(start_id, end_id, verses)
      return [] unless start_id && end_id

      (start_id..end_id).filter_map { |id| verses[id] }
                        .sort_by(&:verse_index)
                        .map(&:verse_key)
    end

    def archive_old_tafsirs(imported_ids)
      Tafsir.where(resource_content_id: @resource.id)
            .where.not(id: imported_ids)
            .update_all(archived: true)
    end
  end
end
