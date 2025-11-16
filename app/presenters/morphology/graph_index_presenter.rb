module Morphology
  class GraphIndexPresenter
    attr_reader :graph

    def initialize(graph)
      @graph = graph
    end

    def collection
      @collection ||= graph&.nodes&.order(:id) || Morphology::GraphNode.none
    end

    def verse_info
      return nil unless graph

      @verse_info ||= {
        chapter: graph.chapter_id.to_s,
        verse: graph.verse_id.to_s,
        verse_key: graph.verse_key,
        graph_number: graph.graph_number,
        total_graphs: total_graphs_in_verse
      }
    end

    def navigation
      return {} unless graph

      @navigation ||= build_navigation
    end

    private

    def build_navigation
      nav = {}

      if next_graph = find_next_graph
        nav[:next_chapter_id] = next_graph.chapter_id
        nav[:next_verse_id] = next_graph.verse_id
        nav[:next_graph_number] = next_graph.graph_number
      end

      if prev_graph = find_previous_graph
        nav[:prev_chapter_id] = prev_graph.chapter_id
        nav[:prev_verse_id] = prev_graph.verse_id
        nav[:prev_graph_number] = prev_graph.graph_number
      end

      nav
    end

    def find_next_graph
      # Try next graph in same verse
      next_graph = Morphology::Graph.where(chapter_id: graph.chapter_id, verse_id: graph.verse_id)
                                    .where('graph_number > ?', graph.graph_number)
                                    .order(:graph_number)
                                    .first
      return next_graph if next_graph

      # Try first graph of next verse in same chapter
      next_graph = Morphology::Graph.where(chapter_id: graph.chapter_id)
                                    .where('verse_id > ?', graph.verse_id)
                                    .order(:verse_id, :graph_number)
                                    .first
      return next_graph if next_graph

      # Try first graph of first verse in next chapter
      Morphology::Graph.where('chapter_id > ?', graph.chapter_id)
                       .order(:chapter_id, :verse_id, :graph_number)
                       .first
    end

    def find_previous_graph
      # Try previous graph in same verse
      prev_graph = Morphology::Graph.where(chapter_id: graph.chapter_id, verse_id: graph.verse_id)
                                    .where('graph_number < ?', graph.graph_number)
                                    .order(graph_number: :desc)
                                    .first
      return prev_graph if prev_graph

      # Try last graph of previous verse in same chapter
      prev_graph = Morphology::Graph.where(chapter_id: graph.chapter_id)
                                    .where('verse_id < ?', graph.verse_id)
                                    .order(verse_id: :desc, graph_number: :desc)
                                    .first
      return prev_graph if prev_graph

      # Try last graph of last verse in previous chapter
      Morphology::Graph.where('chapter_id < ?', graph.chapter_id)
                       .order(chapter_id: :desc, verse_id: :desc, graph_number: :desc)
                       .first
    end

    def total_graphs_in_verse
      Morphology::Graph.where(chapter_id: graph.chapter_id, verse_id: graph.verse_id).count
    end
  end
end
