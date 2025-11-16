module Morphology
  class TreebankController < ApplicationController
    before_action :set_chapter_verse_and_graph_number, only: [:index, :svg, :edit, :update]

    def index
      handle_verse_key_search if params[:verse_key].present?

      @graph = Morphology::Graph.find_by(chapter_id: @chapter_id, verse_id: @verse_id, graph_number: @graph_number)
      presenter = Morphology::GraphIndexPresenter.new(@graph)

      @collection = presenter.collection
      @verse_info = presenter.verse_info
      @navigation = presenter.navigation
    end

    def svg
      @graph = Morphology::Graph.find_by(chapter_id: @chapter_id, verse_id: @verse_id, graph_number: @graph_number)
      return unless @graph

      @graph_nodes = @graph.nodes.order(:number)
      @graph_edges = Morphology::GraphNodeEdge.joins(:source, :target)
                                               .where(morphology_graph_nodes: { graph_id: @graph.id })
                                               .distinct

      @graph_data = Morphology::GraphPresenter.new(@graph).to_syntax_graph_json
    end

    def add_node_row
      @graph = Morphology::Graph.find(params[:graph_id])
      @after_node_id = params[:after_node_id]
      presenter = Morphology::GraphEditPresenter.new(@graph)

      @graph_nodes = presenter.nodes

      timestamp = Time.now.to_f.to_s.gsub('.', '_')
      temp_id = "new_#{timestamp}_#{rand(10000)}"
      temp_number_str = "new-number-#{timestamp}"

      @new_node = Morphology::GraphNode.new(
        graph_id: @graph.id,
        type: 'elided',
        value: '',
        pos: ''
      )
      @new_node.temp_id = temp_id
      @new_node.temp_number = temp_number_str

      @node_types = presenter.node_types
      @available_words = presenter.available_words
      @available_segments = presenter.available_segments

      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.after(
            "node_#{@after_node_id}",
            partial: 'morphology/treebank/node_row',
            locals: {
              node: @new_node,
              graph_nodes: @graph_nodes,
              node_types: @node_types,
              available_words: @available_words,
              available_segments: @available_segments,
              graph_id: @graph.id
            }
          )
        end
      end
    end

    def update_node_fields
      @graph = Morphology::Graph.find(params[:graph_id])
      @node_id = params[:node_id]
      @node_type = params[:node_type]
      presenter = Morphology::GraphEditPresenter.new(@graph)

      @graph_nodes = presenter.nodes

      is_new_node = @node_id.to_s.start_with?('new_')
      @field_name_prefix = is_new_node ? "new_nodes[#{@node_id}]" : "nodes[#{@node_id}]"

      @available_words = presenter.available_words
      @available_segments = presenter.available_segments
      @available_node_numbers = @graph_nodes.reject { |n| n.number.to_s.start_with?('new-number-') }
                                            .map { |n| ["n#{n.number + 1}", n.number + 1] }

      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.update(
            "node_#{@node_id}_fields",
            partial: "morphology/treebank/form/#{@node_type}_fields",
            locals: {
              node_id: @node_id,
              field_name_prefix: @field_name_prefix,
              available_words: @available_words,
              available_segments: @available_segments,
              available_node_numbers: @available_node_numbers,
              resource_id: nil,
              segment_id: nil,
              value: '',
              pos: '',
              phrase_pos: '',
              phrase_source: nil,
              phrase_target: nil
            }
          )
        end
      end
    end

    def edit
      @graph = Morphology::Graph.find_by(chapter_id: @chapter_id, verse_id: @verse_id, graph_number: @graph_number)
      return unless @graph

      @presenter = Morphology::GraphEditPresenter.new(@graph)
      @graph_nodes = @presenter.nodes
      @graph_edges = @presenter.edges
      @node_types = @presenter.node_types
      @available_nodes = @presenter.available_nodes
      @available_words = @presenter.available_words
      @available_segments = @presenter.available_segments
      @available_edges = @presenter.available_edges
      @edge_relations = @presenter.edge_relations
      @resource_types = @presenter.resource_types
    end

    def update
      @graph = Morphology::Graph.find_by(chapter_id: @chapter_id, verse_id: @verse_id, graph_number: @graph_number)
      return unless @graph

      updater = Morphology::GraphBulkUpdater.new(@graph, params)

      if updater.update
        redirect_to morphology_treebank_index_path(
          chapter_id: @chapter_id, 
          verse_id: @verse_id, 
          graph_number: @graph_number
        ), notice: 'Graph updated successfully.'
      else
        flash.now[:alert] = "Errors: #{updater.errors.join('; ')}"
        @presenter = Morphology::GraphEditPresenter.new(@graph)
        @graph_nodes = @presenter.nodes
        @graph_edges = @presenter.edges
        @node_types = @presenter.node_types
        @available_nodes = @presenter.available_nodes
        @available_words = @presenter.available_words
        @available_segments = @presenter.available_segments
        @available_edges = @presenter.available_edges
        @edge_relations = @presenter.edge_relations
        @resource_types = @presenter.resource_types
        render :edit
      end
    end

    def syntax_graph
      chapter_id = (params[:chapter_id] || 1).to_i
      verse_id = (params[:verse_id] || 1).to_i
      graph_number = (params[:graph_number] || 1).to_i

      graph = Morphology::Graph.find_by(chapter_id: chapter_id, verse_id: verse_id, graph_number: graph_number)

      if graph
        presenter = Morphology::GraphPresenter.new(graph)
        render json: presenter.to_syntax_graph_json
      else
        render json: { error: 'Graph not found' }, status: :not_found
      end
    end

    private

    def set_chapter_verse_and_graph_number
      @chapter_id = (params[:chapter_id] || 1).to_i
      @verse_id = (params[:verse_id] || 1).to_i
      @graph_number = (params[:graph_number] || 1).to_i
    end

    def handle_verse_key_search
      verse_key = params[:verse_key].strip
      parts = verse_key.split(':')

      if parts.length >= 2
        chapter_id = parts[0].to_i
        verse_id = parts[1].to_i

        graph = Morphology::Graph.for_verse(chapter_id, verse_id).ordered.first

        if graph
          redirect_to morphology_treebank_index_path(
            chapter_id: graph.chapter_id, 
            verse_id: graph.verse_id, 
            graph_number: graph.graph_number
          )
        else
          flash.now[:alert] = "No graph found for verse #{chapter_id}:#{verse_id}"
        end
      else
        flash.now[:alert] = "Invalid verse key format. Use chapter:verse (e.g., 1:1)"
      end
    end
  end
end
