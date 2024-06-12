# == Schema Information
#
# Table name: translated_names
#
#  id                :integer          not null, primary key
#  language_name     :string
#  language_priority :integer
#  name              :string
#  resource_type     :string
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  language_id       :integer
#  resource_id       :integer
#
# Indexes
#
#  index_translated_names_on_language_id                    (language_id)
#  index_translated_names_on_language_priority              (language_priority)
#  index_translated_names_on_resource_type_and_resource_id  (resource_type,resource_id)
#
class TranslatedName < QuranApiRecord
  include StripWhitespaces
  belongs_to :language
  belongs_to :resource, polymorphic: true

  after_save :fix_priority
  scope :english, -> {where(language_id: 38)}
  protected

  def fix_priority
    if language&.name == 'English'
      update_columns language_priority: 1, language_name: 'english'
    else
      update_columns language_priority: 3, language_name: language&.name.downcase
    end
  end
end
