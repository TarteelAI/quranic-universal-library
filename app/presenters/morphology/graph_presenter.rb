# frozen_string_literal: true

module Morphology
  class GraphPresenter < ApplicationPresenter
    attr_reader :graph, :locale

    def initialize(graph, locale: 'ar')
      @graph = graph
      @locale = locale
    end

    def to_syntax_graph_json
      {
        graphNumber: graph.graph_number,
        graphCount: total_graphs_in_verse,
        legacyCorpusGraphNumber: graph.graph_number,
        locale: locale,
        words: words_payload,
        edges: edges_payload,
        phraseNodes: phrase_nodes_payload,
        edgeLabels: edge_labels
      }
    end
        
    private

    def word_nodes
      @word_nodes ||= graph.nodes
                           .includes(resource: { word: [:verse, :en_translation], word_segments: [] })
                           .where(type: ['word', 'elided', 'reference'])
                           .order(:number)
    end

    def phrase_nodes
      @phrase_nodes ||= graph.nodes
                             .includes(resource: [:source, :target])
                             .where(type: 'phrase')
                             .order(:number)
    end

    def words_payload
      payload = []

      word_nodes.each do |node|
        word_data = format_word_node(node)

        # Merge consecutive nodes with same location
        if payload.any? && 
           ['word', 'reference'].include?(word_data[:type]) && 
           payload.last[:token] && 
           word_data[:token] &&
           payload.last[:token][:location] == word_data[:token][:location]
          payload.last[:endNode] = word_data[:endNode]
        else
          payload << word_data
        end
      end
      
      payload
    end

    def phrase_nodes_payload
      translations = edge_relation_translations

      phrase_nodes.map do |pnode|
        next unless pnode.resource # Skip if no edge resource

        {
          startNode: pnode.resource.source.number,
          endNode: pnode.resource.target.number,
          phraseTag: pnode.resource.relation,
          label: translations[pnode.resource.relation.to_sym] || pnode.resource.relation
        }
      end.compact
    end

    def edges_payload
      @edges_payload ||= begin
        payload = []
        translations = edge_relation_translations

        graph_edges.each do |edge|
          payload << {
            startNode: edge.source.number,
            endNode: edge.target.number,
            dependencyTag: edge.relation,
            label: translations[edge.relation.to_sym] || edge.relation
          }
        end

        payload
      end
    end

    def edge_labels
      @edge_labels ||= graph_edges.pluck(:relation).compact
    end

    def edge_relation_translations
      @edge_relation_translations ||= I18n.t('morphology.edge_relations', locale: locale, default: {})
    end

    def pos_tag_translation(pos_tag)
      return nil if pos_tag.blank?
      I18n.t("morphology.pos_tags.#{pos_tag}", locale: locale, default: pos_tag)
    end

    def graph_edges
      @graph_edges ||= Morphology::DependencyGraph::GraphNodeEdge
        .includes(:source, :target)
        .joins(:source, :target)
        .where(morphology_dependency_graph_nodes: { graph_id: graph.id })
        .where.not(type: 'phrase')
        .order(:id)
    end

    def format_word_node(node)
      data = {
        type: node.type,
        startNode: node.number,
        endNode: node.number
      }

      if node.type == 'word' || node.type == 'reference'
        data[:token] = format_token(node.resource, node.type) if node.resource
      elsif node.type == 'elided'
        format_elided_node(node, data)
      end

      data
    end

    def format_token(morphology_word, type)
      word = morphology_word.word
      
      {
        location: "#{word.verse.chapter_id}:#{word.verse.verse_number}:#{word.position}",
        phonetic: word.en_transliteration || '',
        translation: word.en_translation&.text || '',
        segments: word.location == '2:2:1' ? [reference_segment(morphology_word)] : token_segments(morphology_word)
      }
    end

    def reference_segment(morphology_word)
      pos_tag = morphology_word.word_segments.first.part_of_speech_key
      {
        arabic: morphology_word.word_segments.pluck(:text_uthmani).join,
        posTag: pos_tag,
        posLabel: pos_tag_translation(pos_tag)
      }
    end

    def token_segments(morphology_word)
      morphology_word.word_segments.map do |segment|
        pos_tag = segment.part_of_speech_key
        {
          arabic: segment.text_uthmani,
          posTag: pos_tag,
          posLabel: pos_tag_translation(pos_tag)
        }
      end
    end

    def format_elided_node(node, data)
      # Parse value like "V(*)" or "V(231)" to extract POS tag and text
      if node.value&.match(/^([A-Z]+)\((.+)\)$/)
        pos_tag = $1
        text = $2
      else
        pos_tag = 'ELIDED'
        text = node.value
      end

      data[:elidedPosTag] = pos_tag
      data[:elidedPosLabel] = pos_tag_translation(pos_tag)

      # Only add elidedText if text is not '*'
      if text != '*'
        data[:elidedText] = text
      end
    end

    def total_graphs_in_verse
      Morphology::DependencyGraph::Graph.where(chapter_number: graph.chapter_number, verse_number: graph.verse_number).count
    end
  end
end
