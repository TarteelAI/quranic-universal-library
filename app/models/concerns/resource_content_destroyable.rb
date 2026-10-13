# frozen_string_literal: true

module ResourceContentDestroyable
  extend ActiveSupport::Concern

  class Blocked < StandardError; end

  def confirmation_name
    name.to_s.strip.presence || id.to_s
  end

  def deletion_blockers
    blockers = []

    # Approved content is live for users, un-approve it first on purpose.
    blockers << 'is approved (un-approve it first)' if approved?

    ayah_recitations = Recitation.where(resource_content_id: id)
    if ayah_recitations.exists?
      blockers << "is still used by #{ayah_recitations.count} ayah recitations (delete the recitation instead)"
    end

    surah_recitations = Audio::Recitation.where(resource_content_id: id)
    if surah_recitations.exists?
      blockers << "is still used by #{surah_recitations.count} surah recitations (delete the recitation instead)"
    end

    mushafs = Mushaf.where(resource_content_id: id)
    blockers << "is still used by #{mushafs.count} mushafs" if mushafs.exists?

    blockers << "is still used by #{downloadable_resources.count} downloadable resources" if downloadable_resources.exists?
    blockers << "is still used by #{user_projects.count} user projects" if user_projects.exists?

    blockers
  end

  # Summary of the rows that `destroy_with_data!` will remove, zero counts
  # left out so the confirmation only lists what is actually affected.
  def deletion_summary
    summary = rows_to_delete.transform_values(&:count)
    summary['Book'] = 1 if book.present?
    summary['Admin todos (will be unlinked)'] = AdminTodo.where(resource_content_id: id).count
    summary['Raw data resources (will be unlinked)'] = RawData::Resource.where(resource_content_id: id).count

    summary.select { |_label, count| count.positive? }
  end

  def destroy_with_data!
    blockers = deletion_blockers
    raise Blocked, "Resource content #{blockers.to_sentence}" if blockers.present?

    lang = language
    was_translation = translation?

    # Drafts and raw data live in the main database, the rest in the Quran
    # database, so this transaction only guarantees atomicity for the latter.
    transaction do
      rows_to_delete.each_value(&:delete_all)

      AdminTodo.where(resource_content_id: id).update_all(resource_content_id: nil)
      RawData::Resource.where(resource_content_id: id).update_all(resource_content_id: nil)
      ResourcePermission.where(resource_content_id: id).delete_all

      # The book, change logs and attached files go with the record itself.
      destroy!
    end

    lang&.update_translations_count if was_translation
    true
  end

  protected

  # Every table that stores rows under a resource content, keyed by the label
  # shown in the confirmation. Order matters: rows that are found through
  # another table (translation footnotes, topic links) come before the table
  # they depend on.
  def rows_to_delete
    translation_ids = Translation.where(resource_content_id: id).select(:id)
    draft_translation_ids = Draft::Translation.where(resource_content_id: id).select(:id)
    topic_ids = Topic.where(resource_content_id: id).select(:id)

    {
      'Footnotes of these translations' => FootNote.where(translation_id: translation_ids),
      'Translations' => Translation.where(resource_content_id: id),
      'Word translations' => WordTranslation.where(resource_content_id: id),
      'Tafsirs' => Tafsir.where(resource_content_id: id),
      'Chapter infos' => ChapterInfo.where(resource_content_id: id),
      'Footnotes' => FootNote.where(resource_content_id: id),
      'Transliterations' => Transliteration.where(resource_content_id: id),
      'Tokens' => Token.where(resource_content_id: id),
      'Media contents' => MediaContent.where(resource_content_id: id),
      'Verse topics' => VerseTopic.where(topic_id: topic_ids),
      'Related topics' => RelatedTopic.where(topic_id: topic_ids).or(RelatedTopic.where(related_topic_id: topic_ids)),
      'Topics' => Topic.where(resource_content_id: id),
      'Uloom contents' => UloomContent.where(resource_content_id: id),
      'Root details' => RootDetail.where(resource_content_id: id),
      'Quran script (by ayah)' => QuranScript::ByVerse.where(resource_content_id: id),
      'Quran script (by word)' => QuranScript::ByWord.where(resource_content_id: id.to_s),
      'Footnotes of draft translations' => Draft::FootNote.where(draft_translation_id: draft_translation_ids),
      'Draft translations' => Draft::Translation.where(resource_content_id: id),
      'Draft footnotes' => Draft::FootNote.where(resource_content_id: id),
      'Draft word translations' => Draft::WordTranslation.where(resource_content_id: id),
      'Draft tafsirs' => Draft::Tafsir.where(resource_content_id: id),
      'Draft contents' => Draft::Content.where(resource_content_id: id),
      'Translated names' => translated_names,
      'Tags' => resource_tags,
      'Change logs' => change_logs
    }
  end
end
