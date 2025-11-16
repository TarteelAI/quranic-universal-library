module Morphology
  class GraphBulkUpdater
    attr_reader :graph, :params, :errors
    
    def initialize(graph, params)
      @graph = graph
      @params = params
      @errors = []
    end
    
    def update
      ActiveRecord::Base.transaction do
        create_new_nodes
        update_existing_nodes
        create_new_edges
        update_existing_edges
        
        raise ActiveRecord::Rollback if errors.any?
      end
      
      errors.empty?
    end
    
    private
    
    def create_new_nodes
      return unless params[:new_nodes].present?
      
      params[:new_nodes].each do |temp_id, node_params|
        max_number = graph.nodes.maximum(:number) || -1
        node = graph.nodes.build(
          node_params.permit(:type, :value, :pos, :resource_type, :resource_id, :segment_id)
        )
        node.number = max_number + 1
        
        if node.save
          create_phrase_edge_for_new_node(node, node_params, temp_id) if node.type == 'phrase'
        else
          errors << "New Node: #{node.errors.full_messages.join(', ')}"
        end
      end
    end
    
    def create_phrase_edge_for_new_node(node, node_params, temp_id)
      return unless node_params[:phrase_source].present? && node_params[:phrase_target].present?
      
      source_node = find_node_by_display_number(node_params[:phrase_source])
      target_node = find_node_by_display_number(node_params[:phrase_target])
      
      edge = Morphology::GraphNodeEdge.create(
        source_id: source_node&.id,
        target_id: target_node&.id,
        relation: node_params[:phrase_pos],
        type: 'phrase'
      )
      
      if edge.persisted?
        node.update(resource_type: 'Morphology::GraphNodeEdge', resource_id: edge.id)
      else
        errors << "New Node #{temp_id} Edge: #{edge.errors.full_messages.join(', ')}"
      end
    end
    
    def update_existing_nodes
      return unless params[:nodes].present?
      
      params[:nodes].each do |node_id, node_params|
        node = graph.nodes.find(node_id)
        
        if node_params[:_destroy] == '1'
          destroy_node(node)
        else
          update_node(node, node_params)
        end
      end
    end
    
    def destroy_node(node)
      if node.type == 'phrase' && node.resource_type == 'Morphology::GraphNodeEdge' && node.resource
        node.resource.destroy
      end
      
      unless node.destroy
        errors << "Node #{node.id}: #{node.errors.full_messages.join(', ')}"
      end
    end
    
    def update_node(node, node_params)
      if node.update(node_params.permit(:type, :value, :pos, :resource_type, :resource_id, :segment_id, :number))
        update_phrase_edge(node, node_params) if node.type == 'phrase'
      else
        errors << "Node #{node.id}: #{node.errors.full_messages.join(', ')}"
      end
    end
    
    def update_phrase_edge(node, node_params)
      return unless node_params[:phrase_source].present? && node_params[:phrase_target].present?
      
      source_node = find_node_by_display_number(node_params[:phrase_source])
      target_node = find_node_by_display_number(node_params[:phrase_target])
      
      unless source_node && target_node
        errors << "Node #{node.id}: Invalid source or target node for phrase"
        return
      end
      
      if node.resource_type == 'Morphology::GraphNodeEdge' && node.resource
        update_existing_edge(node, source_node, target_node, node_params[:phrase_pos])
      else
        create_new_edge(node, source_node, target_node, node_params[:phrase_pos])
      end
    end
    
    def update_existing_edge(node, source_node, target_node, relation)
      unless node.resource.update(
        source_id: source_node.id,
        target_id: target_node.id,
        relation: relation
      )
        errors << "Node #{node.id} Edge: #{node.resource.errors.full_messages.join(', ')}"
      end
    end
    
    def create_new_edge(node, source_node, target_node, relation)
      edge = Morphology::GraphNodeEdge.create(
        source_id: source_node.id,
        target_id: target_node.id,
        relation: relation,
        type: 'phrase'
      )
      
      if edge.persisted?
        node.update(resource_type: 'Morphology::GraphNodeEdge', resource_id: edge.id)
      else
        errors << "Node #{node.id} Edge: #{edge.errors.full_messages.join(', ')}"
      end
    end
    
    def create_new_edges
      return unless params[:new_edges].present?
      
      params[:new_edges].each do |temp_id, edge_params|
        edge = Morphology::GraphNodeEdge.new(
          edge_params.permit(:source_id, :target_id, :relation)
        )
        edge.type = 'word' # Default type for manually created edges
        
        unless edge.save
          errors << "New Edge: #{edge.errors.full_messages.join(', ')}"
        end
      end
    end
    
    def update_existing_edges
      return unless params[:edges].present?
      
      params[:edges].each do |edge_id, edge_params|
        edge = Morphology::GraphNodeEdge.find(edge_id)
        
        if edge_params[:_destroy] == '1'
          unless edge.destroy
            errors << "Edge #{edge.id}: #{edge.errors.full_messages.join(', ')}"
          end
        else
          unless edge.update(edge_params.permit(:source_id, :target_id, :relation))
            errors << "Edge #{edge.id}: #{edge.errors.full_messages.join(', ')}"
          end
        end
      end
    end
    
    def find_node_by_display_number(display_number)
      node_number = display_number.to_i - 1
      graph.nodes.find_by(number: node_number)
    end
  end
end
