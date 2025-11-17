# frozen_string_literal: true

module DraftContent
  class ApproveDraftTafsirJob < ApproveDraftContentJob
    private

    def import_from_legacy_table
      tafsirs = Draft::Tafsir.where(resource_content_id: @resource.id)
      imported_ids = []
      imported_ayahs = {}

      tafsirs.includes(:verse).find_each(batch_size: 500) do |draft|
        next if draft.draft_text.blank? || imported_ayahs[draft.verse_key]

        verse = draft.verse
        tafsir = Tafsir.for_verse(verse, @resource) || Tafsir.new
        set_tafsir_attributes(tafsir, draft, verse)
        tafsir.save(validate: false)

        imported_ids << tafsir.id
        imported_ayahs[draft.verse_key] = true
        draft.ayah_group_list.each { |key| imported_ayahs[key] = true }
        draft.update_column(:imported, true)
      end

      archive_old_tafsirs(imported_ids)
    end

    def import_from_draft_content
      if @draft_id
        draft = Draft::Content.find(@draft_id)
        import_single_tafsir(draft)
      else
        Draft::Content.where(resource_content_id: @resource.id, imported: false)
                      .find_each(batch_size: 500) { |draft| import_single_tafsir(draft) }
      end
    end

    def import_single_tafsir(draft)
      start_loc, end_loc = draft.location.to_s.split('-')
      chapter_str, start_str = start_loc.split(':')
      end_str = end_loc || start_str
      start_num = start_str.to_i
      end_num = end_str.to_i

      verse_keys = (start_num..end_num).map { |v| "#{chapter_str}:#{v}" }

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
        start_verse_id: draft.verse_id,
        end_verse_id: draft.verse_id + (end_num - start_num),
        group_tafsir_id: draft.verse_id,
        group_verses_count: verse_keys.size
      )
      tafsir.save!(validate: false)
      draft.update_column(:imported, true)
    end

    def set_tafsir_attributes(tafsir, draft, verse)
      tafsir.assign_attributes(
        resource_content_id: @resource.id,
        text: draft.draft_text.strip,
        language_id: @resource.language_id,
        language_name: @resource.language_name&.downcase || '',
        resource_name: @resource.name,
        verse: verse,
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
        group_verse_key_from: draft.group_verse_key_from,
        group_verse_key_to: draft.group_verse_key_to,
        group_verses_count: Verse.where(id: draft.start_verse_id..draft.end_verse_id).count,
        group_tafsir_id: draft.group_tafsir_id,
        start_verse_id: draft.start_verse_id,
        end_verse_id: draft.end_verse_id
      )
    end

    def archive_old_tafsirs(imported_ids)
      Tafsir.where(resource_content_id: @resource.id)
            .where.not(id: imported_ids)
            .update_all(archived: true)
    end
  end
end