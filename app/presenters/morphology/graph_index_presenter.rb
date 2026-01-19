module Morphology
  class GraphIndexPresenter < ApplicationPresenter
    attr_reader :graph

    def initialize(graph)
      @graph = graph
    end

    def collection
      @collection ||= graph&.nodes&.order(:id) || Morphology::DependencyGraph::GraphNode.none
    end

    def verse_info
      return nil unless graph

      @verse_info ||= {
        chapter: graph.chapter_number.to_s,
        verse: graph.verse_number.to_s,
        verse_key: graph.verse_key,
        graph_number: graph.graph_number,
        total_graphs: total_graphs_in_verse
      }
    end

    def navigation
      return {} unless graph

      @navigation ||= build_navigation
    end

    def corpus_graph_image_id
      return nil unless graph
      verse_id = graph.verse_id

      prev = Morphology::DependencyGraph::Graph.connection.select_value(<<~SQL).to_i
        SELECT COALESCE(SUM(t.max_graph_number), 0) AS total
        FROM (
          SELECT MAX(graph_number) AS max_graph_number
          FROM morphology_dependency_graphs
          WHERE verse_id < #{Morphology::DependencyGraph::Graph.connection.quote(verse_id)}
          GROUP BY verse_id
        ) t
      SQL

      prev + (graph.graph_number.to_i)
    end

    private

    def build_navigation
      nav = {}

      if next_graph = find_next_graph
        nav[:next_id] = next_graph.id
      end

      if prev_graph = find_previous_graph
        nav[:prev_id] = prev_graph.id
      end

      nav
    end

    def find_next_graph
      next_graph = Morphology::DependencyGraph::Graph
                     .where(
                       chapter_number: graph.chapter_number,
                       verse_number: graph.verse_number
                     )
                     .where('graph_number > ?', graph.graph_number)
                     .order(:graph_number)
                     .first

      return next_graph if next_graph

      next_graph = Morphology::DependencyGraph::Graph.where(chapter_number: graph.chapter_number)
                                    .where('verse_number > ?', graph.verse_number)
                                    .order(:verse_number, :graph_number)
                                    .first
      return next_graph if next_graph

      Morphology::DependencyGraph::Graph
        .where('chapter_number > ?', graph.chapter_number)
        .order(:chapter_number, :verse_number, :graph_number)
        .first
    end

    def find_previous_graph
      prev_graph = Morphology::DependencyGraph::Graph
                     .where(
                       chapter_number: graph.chapter_number,
                       verse_number: graph.verse_number
                     )
                     .where('graph_number < ?', graph.graph_number)
                     .order(graph_number: :desc)
                     .first

      return prev_graph if prev_graph

      prev_graph = Morphology::DependencyGraph::Graph.where(chapter_number: graph.chapter_number)
                                    .where('verse_number < ?', graph.verse_number)
                                    .order(verse_number: :desc, graph_number: :desc)
                                    .first
      return prev_graph if prev_graph

      Morphology::DependencyGraph::Graph
        .where('chapter_number < ?', graph.chapter_number)
        .order(
          chapter_number: :desc,
          verse_number: :desc,
          graph_number: :desc
        )
        .first
    end

    def total_graphs_in_verse
      Morphology::DependencyGraph::Graph.where(
        chapter_number: graph.chapter_number,
        verse_number: graph.verse_number
      ).count
    end
  end
end
