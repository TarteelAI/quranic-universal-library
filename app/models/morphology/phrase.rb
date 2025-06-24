# == Schema Information
#
# Table name: morphology_phrases
#
#  id                   :bigint           not null, primary key
#  approved             :boolean          default(FALSE)
#  chapters_count       :integer
#  occurrence           :integer
#  phrase_type          :integer
#  review_status        :string
#  source               :integer
#  text_qpc_hafs        :string
#  text_qpc_hafs_simple :string
#  verses_count         :integer
#  word_position_from   :integer
#  word_position_to     :integer
#  words_count          :integer
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  source_verse_id      :integer
#
# Indexes
#
#  index_morphology_phrases_on_approved            (approved)
#  index_morphology_phrases_on_phrase_type         (phrase_type)
#  index_morphology_phrases_on_source_verse_id     (source_verse_id)
#  index_morphology_phrases_on_word_position_from  (word_position_from)
#  index_morphology_phrases_on_word_position_to    (word_position_to)
#  index_morphology_phrases_on_words_count         (words_count)
#
class Morphology::Phrase < ApplicationRecord
  PHRASE_COLORS = [
    '#0498CC',
    '#7695E5',
    '#9D85FF',
    '#B337FF',
    '#DC65E7',
    '#D47A27',
    '#A1B623',
    '#26B190',
    '#6288C0',
    '#B085C7',
    '#8373E2',
    '#C081BA',
  ]

  has_many :phrase_verses, dependent: :delete_all
  belongs_to :source_verse, class_name: 'Verse', optional: true

  scope :approved, -> {where approved: true}
  after_commit :update_verses_stats, on: [:create, :update]

  def update_verses_stats
    verses = phrase_verses.approved.map(&:verse)

    attrs = {
      occurrence: phrase_verses.approved.size,
      chapters_count: verses.pluck(:chapter_id).uniq.size,
      verses_count: verses.uniq.size,
    }

    if word_position_to && word_position_from
      attrs[:words_count] = (word_position_to - word_position_from) + 1
    else
      attrs[:words_count] = text_qpc_hafs_simple.to_s.split(/\s+/).size
    end

    update_columns(attrs)
  end

  def get_color
    return @color if @color

    color_index = djb2_hash(id.to_s)
    PHRASE_COLORS[ color_index % PHRASE_COLORS.size ]
  end

  def similar_phrases
    scope = Morphology::Phrase.where.not(id: id)
    scope = scope.where("text_qpc_hafs_simple like ?", "%#{text_qpc_hafs_simple}%")

    phrase_verses.approved.each do |v|
      scope = scope.or(scope.where("text_qpc_hafs_simple like ?", "%#{v.text}%"))
    end

    scope
  end

  def chapters
    data = {}
    phrase_verses.order('verse_id ASC').each do |v|
      data[v.verse.chapter_id] ||= {
        chapter: v.verse.chapter,
        count: 0
      }

      data[v.verse.chapter_id][:count] += 1
    end

    data
  end

  def verses(eager_load: :words)
    mapping = {}
    Verse.joins(eager_load).order('verses.id ASC').where(id: phrase_verses.pluck(:verse_id)).each do |v|
      mapping[v.id] = v
    end

    mapping
  end

  def verses_with_matched_phrases
    # verses and their phrases are in two different databases
    mapping = {}
    Verse.includes(:words).order('verses.id ASC').where(id: phrase_verses.pluck(:verse_id)).each do |v|
      mapping[v.id] = {
        verse: v,
        phrase_verses: v.phrase_verses.approved.order('matched_words_count DESC').eager_load(:phrase)
      }
    end

    mapping.values
  end

  def self.auto_approve
    Morphology::Phrase.where("words_count >= 3").update_all approved: true

    with_single_ayah = Morphology::Phrase.where(verses_count: 1)
    with_single_ayah.or(Morphology::Phrase.where(occurrence: 1)).update_all approved: false

    Morphology::Phrase.where(occurrence: [nil,0]).each do |p|
      p.update_verses_stats
    end
  end

  protected
  def djb2_hash(str)
    hash = 5381
    str.each_byte do |byte|
      hash = ((hash * 33) ^ byte)
    end
    hash & 0xffffffff
  end
end
