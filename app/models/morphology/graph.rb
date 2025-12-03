# == Schema Information
#
# Table name: morphology_graphs
#
#  id           :bigint           not null, primary key
#  chapter_id   :integer          not null
#  graph_number :integer          default(1), not null
#  verse_id     :integer          not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
# Indexes
#
#  index_morphology_graphs_on_chapter_verse        (chapter_id,verse_id)
#  index_morphology_graphs_on_chapter_verse_graph  (chapter_id,verse_id,graph_number) UNIQUE
#
class Morphology::Graph < QuranApiRecord
  belongs_to :verse, ->(graph) { where(chapter_id: graph.chapter_id) },
             foreign_key: :verse_id, primary_key: :verse_number, class_name: 'Verse', optional: true
  has_many :nodes, class_name: 'Morphology::GraphNode', foreign_key: :graph_id, dependent: :destroy

  validates :chapter_id, presence: true, numericality: { greater_than: 0, less_than_or_equal_to: 114 }
  validates :verse_id, presence: true, numericality: { greater_than: 0, less_than_or_equal_to: 6236 }
  validates :graph_number, presence: true, numericality: { greater_than: 0 }
  validates :graph_number, uniqueness: { scope: [:chapter_id, :verse_id] }

  scope :for_verse, ->(chapter_id, verse_id) { where(chapter_id: chapter_id, verse_id: verse_id) }
  scope :ordered, -> { order(:chapter_id, :verse_id, :graph_number) }

  delegate :verse_key, to: :verse, allow_nil: true

  alias_method :ayah, :verse
end
