module Morphology
  class TreebankController < ApplicationController
    before_action :set_chapter_verse_and_graph_number, only: [:index, :edit]

    def index
      handle_verse_key_search if params[:verse_key].present?

      @graph = Morphology::Graph.find_by(chapter_id: @chapter_id, verse_id: @verse_id, graph_number: @graph_number)
      presenter = Morphology::GraphIndexPresenter.new(@graph)

      @collection = presenter.collection
      @verse_info = presenter.verse_info
      @navigation = presenter.navigation
    end

    def add_node_row
      @graph = Morphology::Graph.find(params[:graph_id])
      after_node_id = params[:after_node_id]

      new_node = Morphology::NodeService.new(@graph).add_after(after_node_id)
      presenter = Morphology::GraphEditPresenter.new(@graph)
      presenter.nodes.reload

      respond_to do |format|
        format.turbo_stream do
          streams = [
            turbo_stream.after(
              "node_#{after_node_id}",
              partial: 'morphology/treebank/forms/node_row',
              locals: { node: new_node, presenter: presenter, graph_id: @graph.id }
            )
          ]
          streams.concat(build_node_update_streams(presenter, @graph.id, from_number: new_node.number + 1))
          render turbo_stream: streams
        end
      end
    end

    def add_phrase_node
      @graph = Morphology::Graph.find(params[:graph_id])

      new_node = Morphology::PhraseNodeService.new(@graph).add
      presenter = Morphology::GraphEditPresenter.new(@graph)
      presenter.nodes.reload

      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.append(
            'phrase_nodes_tbody',
            partial: 'morphology/treebank/forms/phrase_node_row',
            locals: { node: new_node, presenter: presenter, graph_id: @graph.id }
          )
        end
        format.html do
          redirect_to edit_morphology_treebank_index_path(
            chapter_id: @graph.chapter_id,
            verse_id: @graph.verse_id,
            graph_number: @graph.graph_number
          ), notice: 'Phrase node added successfully.'
        end
      end
    end

    def delete_node
      result = Morphology::NodeService.delete(params[:node_id])
      @graph = result[:graph]
      deleted_node_id = result[:node_id]
      deleted_number = result[:number]

      respond_to do |format|
        format.json { head :ok }
        format.turbo_stream do
          presenter = Morphology::GraphEditPresenter.new(@graph)
          presenter.nodes.reload

          streams = [turbo_stream.remove("node_#{deleted_node_id}")]
          streams.concat(build_node_update_streams(presenter, @graph.id, from_number: deleted_number))
          render turbo_stream: streams
        end
        format.html do
          redirect_to edit_morphology_treebank_index_path(
            chapter_id: @graph.chapter_id,
            verse_id: @graph.verse_id,
            graph_number: @graph.graph_number
          ), notice: 'Node deleted successfully.'
        end
      end
    end

    def update_node_fields
      graph = Morphology::Graph.find(params[:graph_id])
      presenter = Morphology::GraphEditPresenter.new(graph)

      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.update(
            "node_#{params[:node_id]}_fields",
            partial: "morphology/treebank/forms/#{params[:node_type]}_fields",
            locals: { node_id: params[:node_id], presenter: presenter }
          )
        end
      end
    end

    def save_node
      node = Morphology::NodeService.update(params[:node_id], params)

      if node.errors.empty?
        head :ok
      else
        render json: { errors: node.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def save_edge
      edge = Morphology::EdgeService.update(params[:edge_id], params)

      if edge.errors.empty?
        head :ok
      else
        render json: { errors: edge.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def add_edge
      @graph = Morphology::Graph.find(params[:graph_id])

      new_edge = Morphology::EdgeService.new(@graph).add
      presenter = Morphology::GraphEditPresenter.new(@graph)

      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.append(
            'edges_tbody',
            partial: 'morphology/treebank/forms/edge_row',
            locals: { edge: new_edge, presenter: presenter }
          )
        end
      end
    end

    def delete_edge
      deleted_edge_id = Morphology::EdgeService.delete(params[:edge_id])

      respond_to do |format|
        format.json { head :ok }
        format.turbo_stream do
          render turbo_stream: turbo_stream.remove("edge_#{deleted_edge_id}")
        end
      end
    end

    def save_phrase_node
      Morphology::PhraseNodeService.update(params[:node_id], params)
      head :ok
    end

    def edit
      @graph = Morphology::Graph.find_by(chapter_id: @chapter_id, verse_id: @verse_id, graph_number: @graph_number)
      return unless @graph

      @presenter = Morphology::GraphEditPresenter.new(@graph)
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

    def build_node_update_streams(presenter, graph_id, from_number:)
      node_locals = { presenter: presenter, graph_id: graph_id }
      streams = []

      presenter.nodes.each do |node|
        next if node.number < from_number && node.type != 'phrase'

        partial = node.type == 'phrase' ? 'phrase_node_row' : 'node_row'
        streams << turbo_stream.replace(
          "node_#{node.id}",
          partial: "morphology/treebank/forms/#{partial}",
          locals: node_locals.merge(node: node)
        )
      end

      streams
    end
  end
end
