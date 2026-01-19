module Morphology
  class EdgeService
    attr_reader :graph

    def initialize(graph)
      @graph = graph
    end

    def add
      nodes = graph.nodes.order(:number).limit(2)
      source_node = nodes.first
      target_node = nodes.second || nodes.first

      Morphology::DependencyGraph::GraphNodeEdge.create!(
        source_id: source_node&.id,
        target_id: target_node&.id,
        relation: '',
        type: 'word'
      )
    end

    def self.delete(edge_id)
      edge = Morphology::DependencyGraph::GraphNodeEdge.find(edge_id)
      id = edge.id
      edge.destroy!
      id
    end

    def self.update(edge_id, params)
      edge = Morphology::DependencyGraph::GraphNodeEdge.find(edge_id)
      permitted = params.permit(:source_id, :target_id, :relation)
      edge.update(permitted)
      edge
    end
  end
end
