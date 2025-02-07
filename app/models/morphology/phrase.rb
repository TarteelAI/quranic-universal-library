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
#  index_morphology_phrases_on_review_status       (review_status)
#  index_morphology_phrases_on_source_verse_id     (source_verse_id)
#  index_morphology_phrases_on_word_position_from  (word_position_from)
#  index_morphology_phrases_on_word_position_to    (word_position_to)
#  index_morphology_phrases_on_words_count         (words_count)
#
class Morphology::Phrase < ApplicationRecord
  has_many :phrase_verses, dependent: :delete_all
  belongs_to :source_verse, class_name: 'Verse', optional: true

  scope :approved, -> {where approved: true}
  after_commit :update_verses_stats, on: [:create, :update]

  def update_verses_stats
    attrs = {
      occurrence: phrase_verses.pluck(:verse_id).size,
      chapters_count: chapters.keys.size,
      verses_count: phrase_verses.pluck(:verse_id).uniq.size,
    }

    if word_position_to && word_position_from
      attrs[:words_count] = (word_position_to - word_position_from) + 1
    else
      attrs[:words_count] = text_qpc_hafs_simple.to_s.split(/\s+/).size
    end

    update_columns(attrs)
  end

  def color
    return @color if @color
    red = rand(256)
    green = rand(256)
    blue = rand(256)

    # Calculate the luminance (brightness) of the color
    luminance = 0.299 * red + 0.587 * green + 0.114 * blue

    # Ensure sufficient contrast with white background
    while luminance > 200
      red = rand(256)
      green = rand(256)
      blue = rand(256)
      luminance = 0.299 * red + 0.587 * green + 0.114 * blue
    end

    # Convert RGB values to hexadecimal
    @color = "#%02X%02X%02X" % [red, green, blue]
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
end
