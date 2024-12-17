# == Schema Information
#
# Table name: foot_notes
#
#  id                  :integer          not null, primary key
#  language_name       :string
#  text                :text
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  language_id         :integer
#  resource_content_id :integer
#  translation_id      :integer
#
# Indexes
#
#  index_foot_notes_on_language_id          (language_id)
#  index_foot_notes_on_resource_content_id  (resource_content_id)
#  index_foot_notes_on_translation_id       (translation_id)
#
class FootNote < QuranApiRecord
  has_paper_trail on: :update, ignore: [:created_at, :updated_at]
  include Resourceable

  belongs_to :translation
  belongs_to :language

  after_commit :update_translation_footnote_count, on: [:create, :destroy]

  def update_translation_footnote_count
    translation.update_footnote_count
  end
end
