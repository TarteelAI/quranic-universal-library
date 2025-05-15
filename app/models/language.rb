# == Schema Information
#
# Table name: languages
#
#  id                  :integer          not null, primary key
#  direction           :string
#  es_analyzer_default :string
#  es_indexes          :string
#  iso_code            :string
#  name                :string
#  native_name         :string
#  translations_count  :integer
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#
# Indexes
#
#  index_languages_on_iso_code            (iso_code)
#  index_languages_on_translations_count  (translations_count)
#
class Language < QuranApiRecord
  serialize :es_indexes, Array

  has_many :translated_names, as: :resource

  def update_translations_count
    update translations_count: get_translations_count
  end

  def english?
    'en' == iso_code
  end

  def self.find_with_id_or_iso_code(id)
    Language.where(id: id).or(Language.where(iso_code: id)).first
  end

  def get_translations_count
    ResourceContent.translations.one_verse.where(language_id: id).size
  end

  def self.default
    Language.find_by(iso_code: :en)
  end
end
