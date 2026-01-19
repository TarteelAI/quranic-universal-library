# == Schema Information
#
# Table name: morphology_dependency_graph_node_edges
#
#  id         :bigint           not null, primary key
#  relation   :string
#  type       :integer          default("word")
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  source_id  :integer
#  target_id  :integer
#
# Indexes
#
#  index_morphology_dependency_graph_node_edges_on_relation   (relation)
#  index_morphology_dependency_graph_node_edges_on_source_id  (source_id)
#  index_morphology_dependency_graph_node_edges_on_target_id  (target_id)
#  index_morphology_dependency_graph_node_edges_on_type       (type)
#
module Morphology
  module DependencyGraph
    class GraphNodeEdge < QuranApiRecord
      self.table_name = 'morphology_dependency_graph_node_edges'

      self.inheritance_column = :_type

      belongs_to :source, class_name: 'Morphology::DependencyGraph::GraphNode', foreign_key: :source_id, inverse_of: :outgoing_edges
      belongs_to :target, class_name: 'Morphology::DependencyGraph::GraphNode', foreign_key: :target_id, inverse_of: :incoming_edges
      has_one :phrase_node, as: :resource, class_name: 'Morphology::DependencyGraph::GraphNode'

      enum type: {
        word: 0,
        phrase: 1
      }
    end
  end
end

