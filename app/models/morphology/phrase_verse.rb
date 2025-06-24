# == Schema Information
#
# Table name: morphology_phrase_verses
#
#  id                     :bigint           not null, primary key
#  approved               :boolean
#  matched_words_count    :integer
#  missing_word_positions :jsonb
#  review_status          :string
#  similar_words_position :jsonb
#  word_position_from     :integer
#  word_position_to       :integer
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  phrase_id              :integer
#  verse_id               :integer
#
# Indexes
#
#  index_morphology_phrase_verses_on_phrase_id           (phrase_id)
#  index_morphology_phrase_verses_on_verse_id            (verse_id)
#  index_morphology_phrase_verses_on_word_position_from  (word_position_from)
#  index_morphology_phrase_verses_on_word_position_to    (word_position_to)
#
class Morphology::PhraseVerse < ApplicationRecord
  belongs_to :phrase, class_name: 'Morphology::Phrase'
  belongs_to :verse
  scope :approved, -> {where approved: true}
  scope :not_approved, -> {where approved: [false, nil]}

  after_destroy :update_phrase_stats
  after_create :update_phrase_stats

  def create_matching_ayah
    matching = Morphology::MatchingVerse.where(verse_id: phrase.source_verse_id, matched_verse_id: verse_id).first_or_initialize

    if matching.new_record? || matching.matched_word_positions.blank?
      matching.matched_word_positions = (word_position_from..word_position_to).to_a if word_position_from && word_position_to
      matching.save
    end

    matching
  end

  def highlight_word?(word)
    word.position >= word_position_from && word.position <= word_position_to
  end

  def text
    if word_position_from && word_position_to
      verse
        .words
        .where("position >= ? AND position <= ?", word_position_from, word_position_to)
        .pluck(:text_uthmani_simple).join(' ')
    end
  end

  def score
    s = 0
    if approved?
      s += 1
      s += (word_position_to - word_position_from) if 'new' == review_status
      s += (phrase&.approved? ? 7 : 0)
    end

    s += ('new' == review_status ? 10 : 1)
    s += (phrase&.approved? ? 7 : 0)

    s
  end

  protected
  def update_phrase_stats
    phrase&.update_verses_stats
  end
end
