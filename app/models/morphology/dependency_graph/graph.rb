# == Schema Information
#
# Table name: morphology_dependency_graphs
#
#  id             :bigint           not null, primary key
#  chapter_number :integer          not null
#  graph_number   :integer          default(1), not null
#  review_status  :integer          default(NULL), not null
#  verse_number   :integer          not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  verse_id       :integer
#
# Indexes
#
#  index_morphology_dependency_graphs_on_review_status              (review_status)
#  index_morphology_dependency_graphs_on_verse_id                   (verse_id)
#  index_morphology_dependency_graphs_on_verse_id_and_graph_number  (verse_id,graph_number)
#  index_morphology_graphs_on_chapter_verse_graph                   (chapter_number,verse_number,graph_number) UNIQUE
#  index_morphology_graphs_on_chapter_verse_number                  (chapter_number,verse_number)
#
module Morphology
  module DependencyGraph
    class Graph < QuranApiRecord
      self.table_name = 'morphology_dependency_graphs'

      has_many :nodes, class_name: 'Morphology::DependencyGraph::GraphNode', foreign_key: :graph_id, dependent: :destroy
      validates :graph_number, presence: true, numericality: { greater_than: 0 }
      validates :graph_number, uniqueness: { scope: [:chapter_number, :verse_number] }

      enum :review_status, {
        draft: 1,
        approved: 2,
        need_correction: 3
      }, prefix: true

      scope :for_verse, ->(chapter_number, verse_number) { where(chapter_number: chapter_number, verse_number: verse_number) }
      scope :ordered, -> { order(:chapter_number, :verse_number, :graph_number) }

      scope :chapter_eq, ->(chapter_id) { where(chapter_number: chapter_id) }
      scope :verse_eq, ->(verse_id) { joins(:verse).where(verses: { id: verse_id }) }

      def self.ransackable_scopes(*)
        %i[chapter_eq verse_eq]
      end

      def chapter
        @chapter ||= Chapter.find_by(id: chapter_number)
      end

      def verse
        @verse ||= Verse.find_by(id: verse_id) || Verse.find_by(chapter_id: chapter_number, verse_number: verse_number)
      end

      def verse_key
        verse&.verse_key || "#{chapter_number}:#{verse_number}"
      end

      alias_method :ayah, :verse
    end
  end
end

