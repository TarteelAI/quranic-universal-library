module Morphology
  class DependencyGraphNodesController < CommunityController
    def create
      graph = Morphology::DependencyGraph::Graph.find(params[:dependency_graph_id])

      if params[:after_node_id].present?
        after_node_id = params[:after_node_id]
        new_node = Morphology::NodeService.new(graph).add_after(after_node_id)
        presenter = Morphology::GraphEditPresenter.new(graph)
        presenter.nodes.reload

        respond_to do |format|
          format.turbo_stream do
            streams = [
              turbo_stream.after(
                "node_#{after_node_id}",
                partial: 'morphology/dependency_graphs/forms/node_row',
                locals: { node: new_node, presenter: presenter, graph_id: graph.id }
              )
            ]
            streams.concat(build_node_update_streams(presenter, graph.id, from_number: new_node.number + 1))
            render turbo_stream: streams
          end
          format.html do
            redirect_to edit_morphology_dependency_graph_path(graph), notice: 'Node added successfully.'
          end
        end
        return
      end

      if params[:type].to_s == 'phrase'
        new_node = Morphology::PhraseNodeService.new(graph).add
        presenter = Morphology::GraphEditPresenter.new(graph)
        presenter.nodes.reload

        respond_to do |format|
          format.turbo_stream do
            render turbo_stream: turbo_stream.append(
              'phrase_nodes_tbody',
              partial: 'morphology/dependency_graphs/forms/phrase_node_row',
              locals: { node: new_node, presenter: presenter, graph_id: graph.id }
            )
          end
          format.html do
            redirect_to edit_morphology_dependency_graph_path(graph), notice: 'Phrase node added successfully.'
          end
        end
        return
      end

      head :unprocessable_entity
    end

    def update
      graph = Morphology::DependencyGraph::Graph.find(params[:dependency_graph_id])
      node_id = params[:id]

      if params[:phrase_pos].present? || params[:phrase_source].present? || params[:phrase_target].present?
        Morphology::PhraseNodeService.update(node_id, params)
        head :ok
        return
      end

      node = Morphology::NodeService.update(node_id, params)

      if node.errors.empty?
        head :ok
      else
        render json: { errors: node.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def destroy
      result = Morphology::NodeService.delete(params[:id])
      graph = result[:graph]
      deleted_node_id = result[:node_id]
      deleted_number = result[:number]

      respond_to do |format|
        format.json { head :ok }
        format.turbo_stream do
          presenter = Morphology::GraphEditPresenter.new(graph)
          presenter.nodes.reload

          streams = [turbo_stream.remove("node_#{deleted_node_id}")]
          streams.concat(build_node_update_streams(presenter, graph.id, from_number: deleted_number))
          render turbo_stream: streams
        end
        format.html do
          redirect_to edit_morphology_dependency_graph_path(graph), notice: 'Node deleted successfully.'
        end
      end
    end

    def fields
      graph = Morphology::DependencyGraph::Graph.find(params[:dependency_graph_id])
      presenter = Morphology::GraphEditPresenter.new(graph)

      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.update(
            "node_#{params[:id]}_fields",
            partial: "morphology/dependency_graphs/forms/#{params[:node_type]}_fields",
            locals: { node_id: params[:id], presenter: presenter }
          )
        end
      end
    end

    private

    def build_node_update_streams(presenter, graph_id, from_number:)
      node_locals = { presenter: presenter, graph_id: graph_id }
      streams = []

      presenter.nodes.each do |node|
        next if node.number < from_number && node.type != 'phrase'

        partial = node.type == 'phrase' ? 'phrase_node_row' : 'node_row'
        streams << turbo_stream.replace(
          "node_#{node.id}",
          partial: "morphology/dependency_graphs/forms/#{partial}",
          locals: node_locals.merge(node: node)
        )
      end

      streams
    end
  end
end

