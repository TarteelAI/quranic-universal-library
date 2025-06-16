# frozen_string_literal: true
# DraftContent::ApproveDraftContentJob.perform_now(926)

module DraftContent
  class ApproveDraftContentJob < ApplicationJob
    sidekiq_options retry: 1, backtrace: true

    def perform(id)
      resource = ResourceContent.find(id)
      PaperTrail.enabled = false

      if resource.tafsir?
        approve_draft_tafsirs(resource)
      elsif resource.translation?
        approve_draft_translations(resource)
      else
        PaperTrail.enabled = true

        raise "Unknown resource type: #{resource.resource_type}"
      end

      PaperTrail.enabled = true
      AdminTodo
        .where(resource_content_id: resource.id)
        .update_all(is_finished: true)
    end

    protected

    def approve_draft_tafsirs(resource)
      import_tafsirs(resource)

      issues = resource.run_after_import_hooks
      report_issues(resource, issues)
    end

    def approve_draft_translations(resource)
      PaperTrail.enabled = false

      if resource.one_word?
        import_word_translations(resource)
      else
        import_translations(resource)
      end

      issues = resource.run_after_import_hooks
      report_issues(resource, issues)
    end

    def import_translations(resource)
      language = resource.language

      list = Draft::Translation
               .includes(
                 :verse,
                 :foot_notes
               )
               .where(resource_content_id: resource.id)

      list.find_each do |draft|
        verse = draft.verse
        translation = Translation.where(
          verse_id: draft.verse_id,
          resource_content_id: resource.id
        ).first_or_initialize

        translation.foot_notes.delete_all if translation.persisted?

        translation.text = draft.draft_text.strip
        translation.language_id = language.id
        translation.language_name = language.name.downcase
        translation.resource_name = resource.name if translation.resource_name.blank?
        translation.priority = resource.priority || 5
        translation.verse_key = verse.verse_key
        translation.chapter_id = verse.chapter_id
        translation.verse_number = verse.verse_number
        translation.juz_number = verse.juz_number
        translation.hizb_number = verse.hizb_number
        translation.rub_el_hizb_number = verse.rub_el_hizb_number
        translation.ruku_number = verse.ruku_number
        translation.surah_ruku_number = verse.surah_ruku_number
        translation.manzil_number = verse.manzil_number
        translation.page_number = verse.page_number
        translation.save(validate: false)

        import_footnotes(draft, translation, language, resource)
        draft.update_column(:imported, true)
      end
    end

    def import_word_translations(resource)
      # TODO: handle group words translation
      language = resource.language

      list = Draft::WordTranslation
               .includes(
                 :word,
               )
               .where(resource_content_id: resource.id)

      list.find_each do |draft|
        word = draft.word
        translation = WordTranslation.where(
          word_id: word.id,
          resource_content_id: resource.id
        ).first_or_initialize

        translation.text = draft.draft_text.strip
        translation.language_id = language.id
        translation.language_name = language.name.downcase
        translation.priority = resource.priority || 5
        translation.save(validate: false)

        draft.update_column(:imported, true)
      end
    end

    def import_footnotes(draft_translation, translation, language, translation_resource)
      return if draft_translation.foot_notes.blank?

      footnote_resource_id = draft_translation.foot_notes.first.resource_content&.id
      footnote_resource_id ||= translation_resource.meta_value('related-footnote-resource-id')
      text = translation.text

      draft_translation.foot_notes.each do |draft_footnote|
        imported_foot_note = FootNote.create(
          text: draft_footnote.draft_text,
          translation: translation,
          language: language,
          language_name: language.name.downcase,
          resource_content_id: footnote_resource_id
        )

        text = text.sub "foot_note=#{draft_footnote.id}>", "foot_note=#{imported_foot_note.id}>"
      end

      translation.update_column :text, text.strip
    end

    def import_tafsirs(resource)
      tafsirs =  Draft::Tafsir
                   .where(resource_content_id: resource.id)
      tafsirs.update_all(imported: false)

      language = resource.language
      imported_ids = []
      imported_ayahs = {}

      tafsirs.includes(:verse).find_each(batch_size: 500) do |draft|
        next if draft.draft_text.blank? || imported_ayahs[draft.verse_key]

        verse = draft.verse
        tafsir = Tafsir.for_verse(verse, resource) || Tafsir.new

        tafsir.resource_content_id = resource.id
        tafsir.text = draft.draft_text.strip
        tafsir.language_id = language.id
        tafsir.language_name = language.name.downcase
        tafsir.resource_name = resource.name if tafsir.resource_name.blank?

        tafsir.archived = false
        tafsir.verse = verse
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

        tafsir.group_verse_key_from = draft.group_verse_key_from
        tafsir.group_verse_key_to = draft.group_verse_key_to
        tafsir.group_verses_count = Verse.where("id >= ? AND id <= ?", draft.start_verse_id, draft.end_verse_id).count
        tafsir.group_tafsir_id = draft.group_tafsir_id
        tafsir.start_verse_id = draft.start_verse_id
        tafsir.end_verse_id = draft.end_verse_id

        tafsir.save(validate: false)
        imported_ids << tafsir.id

        imported_ayahs[draft.verse_key] = true
        draft.ayah_group_list.each do |key|
          imported_ayahs[key] = true
        end

        draft.update_column(:imported, true)
      end

      # Archive previous tafsir items that are not updated with this bulk import
      Tafsir
        .where(
          resource_content_id: resource.id
        ).where
        .not(id: imported_ids)
        .update_all(archived: true)
    end

    def report_issues(resource, issues)
      body = if issues.present?
               summary = issues.first(3).join(', ')
               "Imported latest changes. Found  #{issues.size} issues after imports: #{summary}. \n <a href='/cms/admin_todos?q%5Bresource_content_id_eq%5D=#{resource.id}&order=id_desc'>See more in the admin todo</a>."
             else
               "Imported latest changes."
             end

      ActiveAdmin::Comment.create(
        namespace: 'cms',
        resource: resource,
        author_type: 'User',
        author_id: 1,
        body: body
      )
    end
  end
end
