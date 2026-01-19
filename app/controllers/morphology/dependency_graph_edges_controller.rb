module Morphology
  class DependencyGraphEdgesController < CommunityController
    def create
      graph = Morphology::DependencyGraph::Graph.find(params[:dependency_graph_id])
      new_edge = Morphology::EdgeService.new(graph).add
      presenter = Morphology::GraphEditPresenter.new(graph)

      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.append(
            'edges_tbody',
            partial: 'morphology/dependency_graphs/forms/edge_row',
            locals: { edge: new_edge, presenter: presenter }
          )
        end
        format.html do
          redirect_to edit_morphology_dependency_graph_path(graph), notice: 'Edge added successfully.'
        end
      end
    end

    def update
      edge = Morphology::EdgeService.update(params[:id], params)

      if edge.errors.empty?
        head :ok
      else
        render json: { errors: edge.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def destroy
      deleted_edge_id = Morphology::EdgeService.delete(params[:id])

      respond_to do |format|
        format.json { head :ok }
        format.turbo_stream do
          render turbo_stream: turbo_stream.remove("edge_#{deleted_edge_id}")
        end
        format.html do
          graph = Morphology::DependencyGraph::Graph.find(params[:dependency_graph_id])
          redirect_to edit_morphology_dependency_graph_path(graph), notice: 'Edge deleted successfully.'
        end
      end
    end
  end
end

