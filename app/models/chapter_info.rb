# == Schema Information
#
# Table name: chapter_infos
#
#  id                  :integer          not null, primary key
#  language_name       :string
#  short_text          :text
#  source              :string
#  text                :text
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  chapter_id          :integer
#  language_id         :integer
#  resource_content_id :integer
#
# Indexes
#
#  index_chapter_infos_on_chapter_id           (chapter_id)
#  index_chapter_infos_on_language_id          (language_id)
#  index_chapter_infos_on_resource_content_id  (resource_content_id)
#
class ChapterInfo < QuranApiRecord
  has_paper_trail on: :update, ignore: [:created_at, :updated_at]
  include Resourceable

  belongs_to :chapter
  belongs_to :language

  def surah_name
    chapter.name_simple
  end
end
