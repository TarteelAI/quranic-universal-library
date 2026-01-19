# == Schema Information
#
# Table name: morphology_graphs
#
#  id             :bigint           not null, primary key
#  chapter_number :integer          not null
#  graph_number   :integer          default(1), not null
#  verse_number   :integer          not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#
# Indexes
#
#  index_morphology_graphs_on_chapter_verse        (chapter_number,verse_number)
#  index_morphology_graphs_on_chapter_verse_graph  (chapter_number,verse_number,graph_number) UNIQUE
#
class Morphology::Graph < QuranApiRecord
  has_many :nodes, class_name: 'Morphology::GraphNode', foreign_key: :graph_id, dependent: :destroy
  validates :graph_number, presence: true, numericality: { greater_than: 0 }
  validates :graph_number, uniqueness: { scope: [:chapter_number, :verse_number] }

  scope :for_verse, ->(chapter_number, verse_number) { where(chapter_number: chapter_number, verse_number: verse_number) }
  scope :ordered, -> { order(:chapter_number, :verse_number, :graph_number) }

  scope :chapter_eq, ->(chapter_id) { where(chapter_number: chapter_id) }
  scope :verse_eq, ->(verse_id) { joins(:verse).where(verses: { id: verse_id }) }

  def self.ransackable_scopes(auth_object = nil)
    %i[chapter_eq verse_eq]
  end

  def chapter
    @chapter ||= Chapter.find_by(id: chapter_number)
  end

  def verse
    @verse ||= Verse.find_by(chapter_id: chapter_number, verse_number: verse_number)
  end

  def verse_key
    verse&.verse_key || "#{chapter_number}:#{verse_number}"
  end

  alias_method :ayah, :verse
end
