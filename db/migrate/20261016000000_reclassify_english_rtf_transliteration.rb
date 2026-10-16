class ReclassifyEnglishRtfTransliteration < ActiveRecord::Migration[8.0]
  RESOURCE_ID = 470
  TRANSLATION_TYPE = 'translation'
  TRANSLITERATION_TYPE = 'transliteration'
  TRANSLATION_TAG = 'Translation'
  TRANSLITERATION_TAG = 'Transliteration'

  attr_writer :resource_model, :tag_model, :tagging_model

  def up
    reclassify_resource(
      resource_type: TRANSLITERATION_TYPE,
      removed_tag_name: TRANSLATION_TAG,
      added_tag_name: TRANSLITERATION_TAG
    )
  end

  def down
    reclassify_resource(
      resource_type: TRANSLATION_TYPE,
      removed_tag_name: TRANSLITERATION_TAG,
      added_tag_name: TRANSLATION_TAG
    )
  end

  private

  def reclassify_resource(resource_type:, removed_tag_name:, added_tag_name:)
    resource = resource_model.find_by(id: RESOURCE_ID)
    return unless resource

    removed_tag = tag_model.find_by!(name: removed_tag_name)
    added_tag = tag_model.find_by!(name: added_tag_name)

    resource.update!(resource_type: resource_type)
    tagging_model.where(
      downloadable_resource_id: RESOURCE_ID,
      downloadable_resource_tag_id: removed_tag.id
    ).delete_all
    tagging_model.find_or_create_by!(
      downloadable_resource_id: RESOURCE_ID,
      downloadable_resource_tag_id: added_tag.id
    )
  end

  def resource_model
    @resource_model ||= DownloadableResource
  end

  def tag_model
    @tag_model ||= DownloadableResourceTag
  end

  def tagging_model
    @tagging_model ||= DownloadableResourceTagging
  end
end
