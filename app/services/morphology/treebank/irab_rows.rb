module Morphology
  module Treebank
    class IrabRows
      attr_reader :head_map

      def initialize(tokens, chapter_number:, verse_number:)
        @tokens         = tokens
        @chapter_number = chapter_number
        @verse_number   = verse_number

        @head_map = {}
        tokens.each do |t|
          id = t_attr(t, :id)
          @head_map[id] = t if id
        end
      end

      def rows
        surface = @tokens.select do |t|
          type = t_attr(t, :token_type).to_s
          ch   = t_attr(t, :chapter_number)
          v    = t_attr(t, :verse_number)
          type == 'surface' && ch == @chapter_number && v == @verse_number
        end

        grouped = surface.group_by do |t|
          [t_attr(t, :verse_number), t_attr(t, :word_number)]
        end

        grouped.sort_by { |(_vn, wn), _| wn.to_i }.map do |_, word_tokens|
          { word_tokens: word_tokens.sort_by { |t| t_attr(t, :position_in_word).to_i } }
        end
      end

      private

      def t_attr(obj, key)
        if obj.respond_to?(key)
          obj.public_send(key)
        elsif obj.respond_to?(:[])
          obj[key]
        end
      end
    end
  end
end
