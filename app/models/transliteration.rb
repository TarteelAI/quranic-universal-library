# == Schema Information
#
# Table name: transliterations
#
#  id                  :integer          not null, primary key
#  language_name       :string
#  text                :text
#  verse_key           :string
#  verse_number        :integer
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  chapter_id          :integer
#  language_id         :integer
#  resource_content_id :integer
#  verse_id            :integer          not null
#
# Indexes
#
#  index_transliterations_on_language_id                       (language_id)
#  index_transliterations_on_resource_content_id               (resource_content_id)
#  index_transliterations_on_resource_content_id_and_verse_id  (resource_content_id,verse_id) UNIQUE
#  index_transliterations_on_verse_id                          (verse_id)
#
# Ayah by ayah transliteration. Word by word transliterations are in WordTransliteration.
class Transliteration < QuranApiRecord
  include StripWhitespaces
  include Resourceable

  has_paper_trail on: :update, ignore: [:created_at, :updated_at]

  belongs_to :verse
  belongs_to :language

  before_save :set_verse_fields, if: :verse_id_changed?

  protected

  def set_verse_fields
    self.verse_key = verse.verse_key
    self.chapter_id = verse.chapter_id
    self.verse_number = verse.verse_number
  end
end
