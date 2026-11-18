module Morphology
  module Treebank
    # Lays the i'rab table out the way NoorBayan's iirab.py does: one row per
    # surface word of every sentence shown in the tree (a sentence can span
    # several ayahs, and the tree above draws all of it), with the phrase
    # lines of constituents attached to the word NoorBayan names in `loc1`.
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
        @rows ||= begin
          phrases = phrases_by_word
          surface = @tokens.select { |t| t_attr(t, :token_type).to_s == 'surface' }

          surface
            .group_by { |t| word_key(t) }
            .sort_by { |(ch, vn, wn), _| [ch.to_i, vn.to_i, wn.to_i] }
            .map do |key, word_tokens|
              ch, vn, = key
              {
                verse_key: "#{ch}:#{vn}",
                current: ch == @chapter_number && vn == @verse_number,
                word_tokens: word_tokens.sort_by { |t| t_attr(t, :position_in_word).to_i },
                phrase_tokens: phrases.fetch(key, [])
              }
            end
        end
      end

      # The خبر that points at `token`, if `token` is the مبتدأ of a nominal
      # sentence. Only a bare `pred`; `pred<<kan>>` is the خبر of a governor.
      def predicate_for(token)
        predicates[t_attr(token, :id)]
      end

      # Its relation is written on its phrase line instead of its own line.
      def phrase_head?(token)
        phrase_attachments.key?(t_attr(token, :id))
      end

      def span_tokens(token)
        span_start = t_attr(token, :constituent_span_start)
        span_end   = t_attr(token, :constituent_span_end)
        return [] if span_start.nil? || span_end.nil?

        sentence_tokens(token).select do |t|
          pos = t_attr(t, :position_in_sentence)
          !pos.nil? && pos >= span_start && pos <= span_end
        end
      end

      private

      def predicates
        @predicates ||= @tokens.each_with_object({}) do |t, map|
          next unless t_attr(t, :rel_label).to_s == 'pred'
          next unless t_attr(t, :rel_governor).to_s.strip.empty?

          head_id = t_attr(t, :head_token_id)
          map[head_id] ||= t if head_id
        end
      end

      # token id => the surface token whose word row carries its phrase line.
      def phrase_attachments
        @phrase_attachments ||= @tokens.each_with_object({}) do |t, map|
          next if t_attr(t, :constituent_label).to_s.strip.empty?
          next if t_attr(t, :constituent_span_end).nil?

          anchor = phrase_anchor(t)
          map[t_attr(t, :id)] = anchor if anchor
        end
      end

      def phrases_by_word
        phrase_attachments.each_with_object(Hash.new { |h, k| h[k] = [] }) do |(id, anchor), map|
          map[word_key(anchor)] << @head_map[id]
        end
      end

      # NoorBayan's loc1 names the token the phrase line goes under (the last
      # one of the phrase). Hidden tokens have no row, so fall back to the last
      # surface token of the phrase before it.
      def phrase_anchor(token)
        meta = t_attr(token, :source_meta) || {}
        loc1 = (meta['loc1'] || meta[:loc1]).to_s
        target = loc1.match?(/\A\d+\z/) ? loc1.to_i : t_attr(token, :constituent_span_end)

        span_start = t_attr(token, :constituent_span_start) || target
        sentence_tokens(token)
          .select { |t| t_attr(t, :token_type).to_s == 'surface' }
          .select { |t| (pos = t_attr(t, :position_in_sentence)) && pos >= span_start && pos <= target }
          .max_by { |t| t_attr(t, :position_in_sentence) }
      end

      def sentence_tokens(token)
        sid = t_attr(token, :sentence_id)
        (@by_sentence ||= @tokens.group_by { |t| t_attr(t, :sentence_id) })[sid] || []
      end

      def word_key(t)
        [t_attr(t, :chapter_number), t_attr(t, :verse_number), t_attr(t, :word_number)]
      end

      def t_attr(obj, key)
        Morphology::Treebank::IrabLine.read_attr(obj, key)
      end
    end
  end
end
