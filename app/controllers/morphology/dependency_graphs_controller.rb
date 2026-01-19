module Morphology
  class DependencyGraphsController < CommunityController
    before_action :authorize_access!, only: [:edit, :split]
    def index
      scope = Verse.all

      if params[:filter_chapter].present?
        scope = scope.where(chapter_id: params[:filter_chapter].to_i)
      end

      if params[:verse_number].present?
        scope = scope.where(verse_number: params[:verse_number].to_i)
      end

      if params[:verse_key].present?
        parts = params[:verse_key].to_s.strip.split(':')
        if parts.length >= 2
          scope = scope.where(chapter_id: parts[0].to_i, verse_number: parts[1].to_i)
        end
      end

      graphs_table = Morphology::DependencyGraph::Graph.arel_table
      verses_table = Verse.arel_table

      join_sql = verses_table
        .join(graphs_table, Arel::Nodes::OuterJoin)
        .on(graphs_table[:verse_id].eq(verses_table[:id]))
        .join_sources

      with_graphs = params[:with_graphs].to_s == '1'
      status_filter = params[:review_status].presence

      select_sql = [
        'verses.id, verses.text_qpc_hafs, verses.verse_key',
        'COUNT(morphology_dependency_graphs.id) AS graphs_count',
        "CASE WHEN COUNT(morphology_dependency_graphs.id) > 0 AND SUM(CASE WHEN morphology_dependency_graphs.review_status = #{Morphology::DependencyGraph::Graph.review_statuses.fetch('approved')} THEN 1 ELSE 0 END) = COUNT(morphology_dependency_graphs.id) THEN 'approved' ELSE 'in_progress' END AS review_status_label",
        'MIN(morphology_dependency_graphs.id) AS first_graph_id'
      ]

      grouped = scope
        .joins(join_sql)
        .select(select_sql.join(', '))
        .group('verses.id')

      grouped = grouped.having('COUNT(morphology_dependency_graphs.id) > 0') if with_graphs

      if status_filter == 'approved'
        grouped = grouped.having(
          "COUNT(morphology_dependency_graphs.id) > 0 AND SUM(CASE WHEN morphology_dependency_graphs.review_status = #{Morphology::DependencyGraph::Graph.review_statuses.fetch('approved')} THEN 1 ELSE 0 END) = COUNT(morphology_dependency_graphs.id)"
        )
      elsif status_filter == 'in_progress'
        grouped = grouped.having(
          "COUNT(morphology_dependency_graphs.id) = 0 OR SUM(CASE WHEN morphology_dependency_graphs.review_status = #{Morphology::DependencyGraph::Graph.review_statuses.fetch('approved')} THEN 1 ELSE 0 END) <> COUNT(morphology_dependency_graphs.id)"
        )
      end

      grouped = grouped.order('verses.verse_index ASC')
      @pagy, @verses = pagy(grouped, items: 100, page: params[:page] || 1)
    end

    def show
      @graph = Morphology::DependencyGraph::Graph.find(params[:id])
      @chapter_number = @graph.chapter_number
      @verse_number = @graph.verse_number
      @graph_number = @graph.graph_number

      presenter = Morphology::GraphIndexPresenter.new(@graph)
      @collection = presenter.collection
      @verse_info = presenter.verse_info
      @navigation = presenter.navigation
      @corpus_graph_image_id = presenter.corpus_graph_image_id
      @compare_mode = params[:compare].to_s == '1'

      respond_to do |format|
        format.html
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace("treebank_compare_button", partial: "morphology/dependency_graphs/compare_button"),
            turbo_stream.replace("treebank_compare_content", partial: "morphology/dependency_graphs/compare_content")
          ]
        end
      end
    end

    def edit
      @graph = Morphology::DependencyGraph::Graph.find(params[:id])
      @chapter_number = @graph.chapter_number
      @verse_number = @graph.verse_number
      @graph_number = @graph.graph_number
      @presenter = Morphology::GraphEditPresenter.new(@graph)
    end

    def lookup
      parts = params[:verse_key].to_s.strip.split(':')
      redirect_to morphology_dependency_graphs_path and return if parts.length < 2

      chapter_number = parts[0].to_i
      verse_number = parts[1].to_i

      graph = Morphology::DependencyGraph::Graph.for_verse(chapter_number, verse_number).ordered.first

      if graph
        redirect_to morphology_dependency_graph_path(graph, locale: params[:locale], compare: params[:compare])
      else
        redirect_to morphology_dependency_graphs_path(locale: params[:locale]), alert: "No graph found for verse #{chapter_number}:#{verse_number}"
      end
    end

    def syntax_graph
      graph = Morphology::DependencyGraph::Graph.find(params[:id])
      presenter = Morphology::GraphPresenter.new(graph, locale: @locale || 'ar')
      render json: presenter.to_syntax_graph_json
    end

    def verse_graphs_data
      graph = Morphology::DependencyGraph::Graph.find(params[:id])
      graphs_data = Morphology::GraphSplitterService.prepare_verse_graphs_data(graph.chapter_number, graph.verse_number)
      render json: { graphs: graphs_data }
    end

    def split
      splitter = Morphology::GraphSplitterService.new(Morphology::DependencyGraph::Graph.find(params[:id]))
      new_graph = splitter.split(params[:node_ids].map(&:to_i))

      if new_graph
        render json: {
          success: true,
          message: "Graph split successfully. New graph ##{new_graph.graph_number} created.",
          new_graph_number: new_graph.graph_number,
          redirect_url: morphology_dependency_graph_path(new_graph)
        }, status: :ok
      else
        render json: { success: false, errors: splitter.errors }, status: :unprocessable_entity
      end
    end

    private

    def set_locale
      @locale = params[:locale] || I18n.locale
    end

    def load_resource_access
      @access = can_manage?(find_resource)
    end

    def find_resource
      @resource ||= ResourceContent.find_by(id: 1612)
    end
  end
end

