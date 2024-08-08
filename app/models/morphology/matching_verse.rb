# == Schema Information
#
# Table name: morphology_matching_verses
#
#  id                     :bigint           not null, primary key
#  approved               :boolean
#  coverage               :integer
#  matched_word_positions :jsonb
#  matched_words_count    :integer
#  score                  :integer
#  words_count            :integer
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  chapter_id             :integer
#  matched_chapter_id     :integer
#  matched_verse_id       :integer
#  verse_id               :integer
#
# Indexes
#
#  index_morphology_matching_verses_on_chapter_id           (chapter_id)
#  index_morphology_matching_verses_on_coverage             (coverage)
#  index_morphology_matching_verses_on_matched_chapter_id   (matched_chapter_id)
#  index_morphology_matching_verses_on_matched_verse_id     (matched_verse_id)
#  index_morphology_matching_verses_on_matched_words_count  (matched_words_count)
#  index_morphology_matching_verses_on_score                (score)
#  index_morphology_matching_verses_on_verse_id             (verse_id)
#  index_morphology_matching_verses_on_words_count          (words_count)
#
class Morphology::MatchingVerse < ApplicationRecord
  belongs_to :chapter, optional: true
  belongs_to :verse
  belongs_to :matched_chapter, class_name: 'Chapter', optional: true
  belongs_to :matched_verse, class_name: 'Verse'

  validates :verse_id, presence: true, uniqueness: { scope: :matched_verse_id }
  validate :no_self_matching

  scope :approved, -> { where approved: true }
  scope :without_matching_words, -> { where(matched_words_count: [nil, 0]).or(where "matched_word_positions = '[]'::jsonb") }

  after_create :calculate_matching_score

  def verse_id=(val)
    self.chapter_id = Verse.find(val).chapter_id
    super val
  end

  def matched_verse_id=(val)
    self.matched_chapter_id = Verse.find(val).chapter_id
    super val
  end

  def is_source_verse?(verse)
    verse_id == verse.id
  end

  def matched_word_positions=(val)
    super val.is_a?(String) ? Oj.load(val) : val
  end

  protected

  def no_self_matching
    errors.add :base, "matching ayah is same as base ayah" if verse_id == matched_verse_id
  end

  def calculate_matching_score
    service = MatchingAyahService.new(verse)

    score = service.calculating_matching_score(matched_verse, use_root: true)
    word_positions = service.get_matching_words(matched_verse, use_root: true)

    update_columns(
      matched_word_positions: word_positions,
      matched_words_count: word_positions.size,
      score: score,
      words_count: matched_verse.words.words.size
    )
  end
end
