# == Schema Information
#
# Table name: word_translations
#
#  id                  :bigint           not null, primary key
#  language_name       :string
#  priority            :integer
#  text                :string
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  language_id         :integer
#  resource_content_id :integer
#  word_id             :integer
#
# Indexes
#
#  index_word_translations_on_priority                 (priority)
#  index_word_translations_on_word_id_and_language_id  (word_id,language_id)
#

class WordTranslation < QuranApiRecord
  include StripWhitespaces
  include Resourceable

  has_paper_trail on: :update, ignore: [:created_at, :updated_at]

  belongs_to :word
  belongs_to :language

  protected
  def attributes_to_strip
    [:language_name, :text]
  end
end
