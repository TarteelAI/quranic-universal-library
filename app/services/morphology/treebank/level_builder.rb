require 'set'

module Morphology
  module Treebank
    class LevelBuilder
      def initialize(tokens)
        @tokens = tokens
      end

      def build
        spans = collect_spans
        level_map = assign_levels(spans)
        phrase_nodes = build_phrase_nodes(level_map)
        max_level = phrase_nodes.map { |n| n[:level] }.max || 0
        top_positions = build_top_positions(phrase_nodes, max_level)
        { phrase_nodes: phrase_nodes, max_level: max_level, top_positions: top_positions }
      end

      private

      def collect_spans
        seen = Set.new
        @tokens.filter_map do |t|
          next if t[:span_start].nil? || t[:span_end].nil?
          key = [t[:span_start], t[:span_end]]
          next if seen.include?(key)
          seen << key
          (t[:span_start]..t[:span_end]).to_a
        end
      end

      def assign_levels(spans)
        return {} if spans.empty?

        main_list = spans.sort_by(&:length)
        sub_levels = []

        until main_list.empty?
          sub_list = []
          until main_list.empty?
            pivot = main_list[0]
            indices = (0...main_list.length).select do |i|
              main_list[i].any? { |pos| pivot.include?(pos) }
            end
            sub_list << main_list.values_at(*indices)
            indices.reverse_each { |i| main_list.delete_at(i) }
          end

          sub_levels << sub_list.map { |group| group[0] }
          leftover = sub_list.flat_map { |group| group[1..] }
          main_list = leftover.sort_by(&:length)
        end

        level_map = {}
        sub_levels.each_with_index do |level_spans, idx|
          level_spans.each do |span|
            level_map[span] = idx + 1
          end
        end
        level_map
      end

      def build_phrase_nodes(level_map)
        nodes = []
        seen = Set.new
        @tokens.each do |t|
          next if t[:span_start].nil? || t[:span_end].nil?
          key = [t[:span_start], t[:span_end]]
          next if seen.include?(key)
          seen << key
          span_array = (t[:span_start]..t[:span_end]).to_a
          level = level_map[span_array]

          nodes << {
            span: [t[:span_start], t[:span_end]],
            label: t[:constituent_label],
            text: t[:constituent_text],
            centroid: (t[:span_start] + t[:span_end]) / 2.0,
            level: level,
            head_position: t[:position]
          }
        end
        nodes
      end

      def build_top_positions(phrase_nodes, max_level)
        covered_positions = Set.new(
          phrase_nodes.flat_map { |n| (n[:span][0]..n[:span][1]).to_a }
        )

        top = []
        @tokens.each do |t|
          top << t[:position] unless covered_positions.include?(t[:position])
        end

        phrase_nodes.select { |n| n[:level] == max_level }.each do |n|
          top << n[:centroid]
        end

        top
      end
    end
  end
end
