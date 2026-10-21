# == Schema Information
#
# Table name: word_transliterations
#
#  id                  :bigint           not null, primary key
#  language_name       :string
#  text                :string
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  language_id         :integer
#  resource_content_id :integer
#  word_id             :integer          not null
#
# Indexes
#
#  index_word_transliterations_on_language_id                      (language_id)
#  index_word_transliterations_on_resource_content_id_and_word_id  (resource_content_id,word_id) UNIQUE
#  index_word_transliterations_on_word_id                          (word_id)
#
class WordTransliteration < QuranApiRecord
  include StripWhitespaces
  include Resourceable

  has_paper_trail on: :update, ignore: [:created_at, :updated_at]

  belongs_to :word
  belongs_to :language

  delegate :location, to: :word
end
