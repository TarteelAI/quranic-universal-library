module Morphology
  class PhraseNodeService
    attr_reader :graph

    def initialize(graph)
      @graph = graph
    end

    def add
      next_number = (graph.nodes.maximum(:number) || -1) + 1

      graph.nodes.create!(
        type: 'phrase',
        value: '',
        pos: '',
        number: next_number
      )
    end

    def self.update(node_id, params)
      node = Morphology::GraphNode.find(node_id)
      new(node.graph).update_node(node, params)
    end

    def update_node(node, params)
      source_number = parse_display_number(params[:phrase_source])
      target_number = parse_display_number(params[:phrase_target])
      relation = params[:phrase_pos]

      source_node = find_node_by_number(source_number)
      target_node = find_node_by_number(target_number)

      update_or_create_edge(node, source_node, target_node, relation)
      update_node_value(node, source_node, target_node, relation)

      node
    end

    private

    def parse_display_number(display_number)
      return nil unless display_number.present?
      display_number.to_i - 1  # Convert 1-indexed display to 0-indexed
    end

    def find_node_by_number(number)
      return nil unless number
      graph.nodes.find_by(number: number)
    end

    def update_or_create_edge(node, source_node, target_node, relation)
      if node.resource_type == 'Morphology::GraphNodeEdge' && node.resource
        node.resource.update(
          source_id: source_node&.id,
          target_id: target_node&.id,
          relation: relation
        )
      elsif source_node && target_node
        edge = Morphology::GraphNodeEdge.create(
          source_id: source_node.id,
          target_id: target_node.id,
          relation: relation,
          type: 'phrase'
        )
        node.update(resource_type: 'Morphology::GraphNodeEdge', resource_id: edge.id)
      end
    end

    def update_node_value(node, source_node, target_node, relation)
      return unless source_node && target_node

      value = graph.nodes
                   .where('number >= ? AND number <= ?', source_node.number, target_node.number)
                   .order(:number)
                   .map(&:value)
                   .join(' ')

      node.update(value: value, pos: relation)
    end
  end
end
