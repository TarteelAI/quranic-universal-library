# frozen_string_literal: true

module Morphology
  class GraphSplitterService
    attr_reader :source_graph, :errors

    def initialize(source_graph)
      @source_graph = source_graph
      @errors = []
    end

    def self.prepare_verse_graphs_data(chapter_number, verse_number)
      graphs = Morphology::DependencyGraph::Graph
        .for_verse(chapter_number, verse_number)
        .includes(nodes: { resource: :word })
        .ordered

      graphs.map do |graph|
        nodes_by_word = {}
        all_nodes = graph.nodes.where(type: ['word', 'elided', 'reference']).order(:number)
        
        all_nodes.each do |node|
          if node.type == 'word' && node.resource&.respond_to?(:word)
            word_id = node.resource.word_id
            if !nodes_by_word[word_id]
              nodes_by_word[word_id] = {
                node: node,
                all_node_ids: [node.id]
              }
            else
              nodes_by_word[word_id][:all_node_ids] << node.id
            end
          else
            nodes_by_word["#{node.type}_#{node.id}"] = {
              node: node,
              all_node_ids: [node.id]
            }
          end
        end

        {
          id: graph.id,
          graph_number: graph.graph_number,
          nodes: nodes_by_word.values.map do |data|
            node = data[:node]
            {
              id: node.id,
              all_node_ids: data[:all_node_ids],
              type: node.type,
              text: node_display_text(node),
              location: node_location(node)
            }
          end.sort_by { |n| n[:id] }
        }
      end
    end

    def self.node_location(node)
      return node.value if node.type == 'elided'
      
      if node.resource&.respond_to?(:word)
        word = node.resource.word
        "#{word.verse.chapter_id}:#{word.verse.verse_number}:#{word.position}"
      else
        "Node #{node.number}"
      end
    end

    def self.node_display_text(node)
      case node.type
      when 'elided'
        node.value || 'Elided'
      when 'word', 'reference'
        if node.resource&.respond_to?(:word)
          word = node.resource.word
          "#{word.text_uthmani} (#{word.en_transliteration})"
        else
          "Word"
        end
      else
        node.type.titleize
      end
    end

    def split(node_ids_for_new_graph)
      return nil if node_ids_for_new_graph.blank?

      ActiveRecord::Base.transaction do
        new_graph = create_new_graph
        nodes_to_move = fetch_nodes_to_move(node_ids_for_new_graph)
        
        validate_split(nodes_to_move)
        return nil if @errors.any?

        move_nodes_to_graph(nodes_to_move, new_graph)
        renumber_nodes(source_graph)
        renumber_nodes(new_graph)
        
        # Clean up any empty graphs for this verse
        cleanup_empty_graphs
        
        new_graph
      end
    rescue ActiveRecord::RecordInvalid => e
      @errors << e.message
      nil
    end

    def success?
      @errors.empty?
    end

    def response_data(new_graph, base_url_helper)
      if new_graph
        {
          success: true,
          message: "Graph split successfully. New graph ##{new_graph.graph_number} created.",
          new_graph_number: new_graph.graph_number,
          redirect_url: base_url_helper.call(
            chapter_number: new_graph.chapter_number,
            verse_number: new_graph.verse_number,
            graph_number: new_graph.graph_number
          )
        }
      else
        {
          success: false,
          errors: @errors
        }
      end
    end

    private

    def create_new_graph
      next_graph_number = Morphology::DependencyGraph::Graph
        .for_verse(source_graph.chapter_number, source_graph.verse_number)
        .maximum(:graph_number).to_i + 1

      Morphology::DependencyGraph::Graph.create!(
        chapter_number: source_graph.chapter_number,
        verse_number: source_graph.verse_number,
        graph_number: next_graph_number
      )
    end

    def fetch_nodes_to_move(node_ids)
      source_graph.nodes.where(id: node_ids)
    end

    def validate_split(nodes_to_move)
      if nodes_to_move.empty?
        @errors << "No valid nodes selected for split"
        return
      end

      remaining_nodes_count = source_graph.nodes.count - nodes_to_move.count
      if remaining_nodes_count.zero?
        @errors << "Cannot move all nodes. Source graph must retain at least one node."
      end
    end

    def move_nodes_to_graph(nodes, target_graph)
      node_ids = nodes.pluck(:id)
      
      Morphology::DependencyGraph::GraphNode.where(id: node_ids).update_all(graph_id: target_graph.id)
      
      edges_to_delete = Morphology::DependencyGraph::GraphNodeEdge
        .where("source_id IN (?) OR target_id IN (?)", node_ids, node_ids)
        .where.not("source_id IN (?) AND target_id IN (?)", node_ids, node_ids)
      
      edges_to_delete.destroy_all
    end

    def renumber_nodes(graph)
      nodes = graph.nodes.where(type: ['word', 'elided', 'reference']).order(:number)
      
      nodes.each_with_index do |node, index|
        node.update_column(:number, index)
      end
    end

    def cleanup_empty_graphs
      verse_graphs = Morphology::DependencyGraph::Graph.for_verse(
        source_graph.chapter_number,
        source_graph.verse_number
      ).order(:graph_number)
      
      deleted_any = false
      verse_graphs.each do |graph|
        node_count = graph.nodes.where(type: ['word', 'elided', 'reference']).count
        if node_count.zero?
          graph.destroy
          deleted_any = true
        end
      end
      
      if deleted_any
        remaining_graphs = Morphology::DependencyGraph::Graph.for_verse(
          source_graph.chapter_number,
          source_graph.verse_number
        ).order(:graph_number)
        
        remaining_graphs.each_with_index do |graph, index|
          graph.update_column(:graph_number, index + 1)
        end
      end
    end
  end
end
