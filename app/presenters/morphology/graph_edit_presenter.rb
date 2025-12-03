module Morphology
  class GraphEditPresenter < ApplicationPresenter
    attr_reader :graph, :chapter_id, :verse_id
    
    def initialize(graph)
      @graph = graph
      @chapter_id = graph.chapter_id
      @verse_id = graph.verse_id
    end

    def nodes
      @nodes ||= graph.nodes.order(:number)
    end

    def edges
      @edges ||= Morphology::GraphNodeEdge.includes(:source, :target)
                                          .joins(:source, :target)
                                          .where(morphology_graph_nodes: { graph_id: graph.id })
                                          .where.not(type: 'phrase')
                                          .distinct
    end

    def node_types
      @node_types ||= Morphology::GraphNode.types.keys.reject { |t| t == 'phrase' }
    end

    def available_nodes
      @available_nodes ||= nodes.map { |n| ["n#{n.number + 1} - #{n.type}: #{n.value}", n.id] }
    end

    def available_words(range: 3)
      @available_words ||= WordsFetcher.new(chapter_id, verse_id, range: range).fetch
    end

    def available_segments(range: 3)
      @available_segments ||= SegmentsFetcher.new(chapter_id, verse_id, range: range).fetch
    end

    def available_edges
      @available_edges ||= edges.map { |e| ["#{e.relation}: n#{e.source.number + 1} → n#{e.target.number + 1}", e.id] }
    end

    def edge_relations
      @edge_relations ||= Morphology::GraphNodeEdge.distinct.pluck(:relation).compact.sort
    end

    def resource_types
      ['Morphology::Word', 'Morphology::GraphNodeEdge']
    end

    class WordsFetcher
      def initialize(chapter_id, verse_id, range: 3)
        @chapter_id = chapter_id
        @verse_id = verse_id
        @range = range
      end
      
      def fetch
        chapter = Chapter.find_by(id: @chapter_id)
        return [] unless chapter

        min_verse = [@verse_id - @range, 1].max
        max_verse = [@verse_id + @range, chapter.verses_count].min

        Morphology::Word.includes(:word)
                        .joins(:verse)
                        .where(verses: { chapter_id: @chapter_id })
                        .where('verses.verse_number >= ? AND verses.verse_number <= ?', min_verse, max_verse)
                        .order(:location)
                        .map { |w| ["#{w.location} - #{w.word.text_uthmani}", w.id] }
      end
    end

    class SegmentsFetcher
      def initialize(chapter_id, verse_id, range: 3)
        @chapter_id = chapter_id
        @verse_id = verse_id
        @range = range
      end

      def fetch
        chapter = Chapter.find_by(id: @chapter_id)
        return [] unless chapter

        min_verse = [@verse_id - @range, 1].max
        max_verse = [@verse_id + @range, chapter.verses_count].min

        Morphology::WordSegment.joins(word: :verse)
                               .where(verses: { chapter_id: @chapter_id })
                               .where('verses.verse_number >= ? AND verses.verse_number <= ?', min_verse, max_verse)
                               .order('morphology_words.location, morphology_word_segments.position')
                               .map { |s| ["#{s.location} - #{s.text_uthmani}", s.id] }
      end
    end
  end
end
