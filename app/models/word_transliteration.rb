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
  
  has_paper_trail on: :update, ignore: [:created_at, :updated_at]

  belongs_to :word
  belongs_to :language
  belongs_to :resource_content

  delegate :location, to: :word

  def self.save_suggestions(verse, resource, texts, user, comment: nil)
    existing = where(resource_content_id: resource.id, word_id: texts.keys).index_by(&:word_id)
    words = verse.words.where(id: texts.keys).index_by(&:id)

    texts.each do |word_id, text|
      word = words[word_id.to_i]
      text = text.to_s.strip
      current_text = existing[word_id.to_i]&.text.to_s
      next if word.blank? || text.blank? || text == current_text

      Draft::WordTransliteration.new(
        verse_id: verse.id,
        word_id: word.id,
        location: word.location,
        resource_content_id: resource.id,
        current_text: current_text,
        draft_text: text,
        text_matched: false,
        need_review: true,
        user_id: user.id,
        comment: comment.to_s.strip.presence
      ).save(validate: false)
    end
  end
end
