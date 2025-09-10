# frozen_string_literal: true

module DraftContent
  class ApproveDraftTranslationJob < ApproveDraftContentJob
    private

    def import_from_legacy_table
      translations = Draft::Translation.includes(:verse, :foot_notes)
                                       .where(resource_content_id: @resource.id)

      translations.find_each do |draft|
        verse = draft.verse
        translation = Translation.where(
          verse_id: draft.verse_id,
          resource_content_id: @resource.id
        ).first_or_initialize

        set_translation_attributes(translation, draft, verse)
        translation.save!(validate: false)
        import_footnotes(draft, translation) if draft.foot_notes.present?
        draft.update_column(:imported, true)
      end
    end

    def import_from_draft_content
      if @draft_id
        draft = Draft::Content.find(@draft_id)
        import_single_translation(draft)
      else
        Draft::Content.where(resource_content_id: @resource.id, imported: false)
                      .find_each { |draft| import_single_translation(draft) }
      end
    end

    def import_single_translation(draft)
      verse = draft.verse
      translation = Translation.where(
        verse_id: verse.id,
        resource_content_id: @resource.id
      ).first_or_initialize

      set_translation_attributes(translation, draft, verse)
      translation.save!(validate: false)
      draft.update_column(:imported, true)
    end

    def set_translation_attributes(translation, draft, verse)
      translation.assign_attributes(
        text: draft.draft_text.strip,
        language_id: @resource.language_id,
        language_name: @resource.language_name&.downcase || '',
        resource_name: @resource.name,
        priority: @resource.priority || 5,
        verse_key: verse.verse_key,
        chapter_id: verse.chapter_id,
        verse_number: verse.verse_number,
        juz_number: verse.juz_number,
        hizb_number: verse.hizb_number,
        rub_el_hizb_number: verse.rub_el_hizb_number,
        ruku_number: verse.ruku_number,
        surah_ruku_number: verse.surah_ruku_number,
        manzil_number: verse.manzil_number,
        page_number: verse.page_number
      )
    end

    def import_footnotes(draft_translation, translation)
      footnote_resource_id = draft_translation.foot_notes.first.resource_content_id ||
                             @resource.meta_value('related-footnote-resource-id')

      text = translation.text
      draft_translation.foot_notes.each do |draft_footnote|
        footnote = FootNote.create!(
          text: draft_footnote.draft_text,
          translation: translation,
          language_id: @resource.language_id,
          language_name: @resource.language_name&.downcase || '',
          resource_content_id: footnote_resource_id
        )
        text = text.sub(/foot_note=(['"]?)#{draft_footnote.id}\1/, "foot_note=#{footnote.id}")
      end

      translation.update_column(:text, text.strip)
    end
  end
end