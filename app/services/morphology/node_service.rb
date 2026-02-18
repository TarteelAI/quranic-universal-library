module Morphology
  class NodeService
    attr_reader :graph

    def initialize(graph)
      @graph = graph
    end

    def add_after(after_node_id)
      after_node = graph.nodes.find(after_node_id)
      new_number = after_node.number + 1

      shift_nodes_up(from_number: new_number)

      graph.nodes.create!(
        type: 'elided',
        value: '',
        pos: '',
        number: new_number
      )
    end

    def self.delete(node_id)
      node = Morphology::DependencyGraph::GraphNode.find(node_id)
      graph = node.graph
      deleted_number = node.number
      deleted_id = node.id

      if node.type == 'phrase' && node.resource_type == 'Morphology::DependencyGraph::GraphNodeEdge' && node.resource
        node.resource.destroy
      end

      node.destroy!
      new(graph).send(:shift_nodes_down, from_number: deleted_number)

      { graph: graph, node_id: deleted_id, number: deleted_number }
    end

    def self.update(node_id, params)
      node = Morphology::DependencyGraph::GraphNode.find(node_id)
      permitted = params.permit(:type, :value, :pos, :resource_id, :segment_id).to_h

      case permitted[:type]
      when 'word', 'reference'
        permitted[:resource_type] = 'Morphology::Word'
      when 'elided'
        permitted[:resource_type] = nil
        permitted[:resource_id] = nil
        permitted[:segment_id] = nil
      end

      node.update(permitted)
      node
    end

    private

    def shift_nodes_up(from_number:)
      graph.nodes.where('number >= ?', from_number).order(number: :desc).each do |node|
        node.update_column(:number, node.number + 1)
      end
    end

    def shift_nodes_down(from_number:)
      graph.nodes.where('number > ?', from_number).order(:number).each do |node|
        node.update_column(:number, node.number - 1)
      end
    end
  end
end
