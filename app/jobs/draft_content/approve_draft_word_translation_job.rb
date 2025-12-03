# frozen_string_literal: true

module DraftContent
  class ApproveDraftWordTranslationJob < ApproveDraftContentJob
    private

    def import_from_legacy_table
      Draft::WordTranslation.includes(:word)
                            .where(resource_content_id: @resource.id)
                            .find_each { |draft| import_word(draft) }
    end

    def import_from_draft_content
      if @draft_id
        draft = Draft::Content.find(@draft_id)
        import_word_draft(draft)
      else
        Draft::Content.where(resource_content_id: @resource.id, imported: false)
                      .find_each { |draft| import_word_draft(draft) }
      end
    end

    def import_word(draft)
      word = draft.word
      translation = WordTranslation.where(
        word_id: word.id,
        resource_content_id: @resource.id
      ).first_or_initialize

      translation.assign_attributes(
        text: draft.draft_text.strip,
        language_id: @resource.language_id,
        language_name: @resource.language_name&.downcase || '',
        priority: @resource.priority || 5
      )
      translation.save!(validate: false)
      draft.update_column(:imported, true)
    end

    def import_word_draft(draft)
      word = draft.word
      translation = WordTranslation.where(
        word_id: word.id,
        resource_content_id: @resource.id
      ).first_or_initialize

      translation.assign_attributes(
        text: draft.draft_text.strip,
        language_id: @resource.language_id,
        language_name: @resource.language_name&.downcase || '',
        priority: @resource.priority || 5,
        group_word_id: draft.meta_data&.dig('group_word_id'),
        group_text: draft.meta_data&.dig('group_text')
      )
      translation.save!(validate: false)
      draft.update_column(:imported, true)
    end
  end
end