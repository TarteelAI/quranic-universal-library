module Morphology
  module Treebank
    # The i'rab of a constituent (verbal sentence, prepositional phrase, ...)
    # as NoorBayan's iirab.py writes it under the word that closes it:
    #
    #   جملة فعلية ﴿ٱسْتَغْفِرُوا۟ رَبَّكُمْ﴾. وهي صلة لحرف المصدري ﴿أَنِ﴾
    #
    # `token` is the token that heads the constituent; its relation and head
    # belong to the phrase as a whole, so IrabLine leaves them off that token's
    # own line.
    class IrabPhraseLine < IrabLine
      def initialize(token, head_token:, span_tokens:, translator:, locale: 'ar')
        super(token, head_token: head_token, translator: translator, locale: locale)
        @span_tokens = span_tokens
      end

      def fragments
        label_key = t_attr(:constituent_label).to_s
        return [] if label_key.empty?

        result = []
        result << frag(
          @translator.call("morphology.edge_relations.#{label_key}", locale: @locale, default: label_key),
          color_class: Morphology::Treebank::Colors.relation(label_key)
        )
        result << frag(' ')
        result << head_reference_fragment(phrase_text)
        result.concat(phrase_dependency_fragments)
        result
      end

      private

      def phrase_dependency_fragments
        frags = dependency_fragments
        return [frag('.')] if frags.empty?

        # dependency_fragments opens with dep_intro ("وهو"), which does not
        # fit a phrase; iirab.py goes straight to the relation.
        intro = t('phrase_dep_intro', default: '')
        frags[0] = frag(intro) unless intro.to_s.empty?
        frags
      end

      # Rebuilt from the tokens, in the same script as the rest of the table,
      # rather than NoorBayan's own (often unvocalised) constituent string.
      def phrase_text
        words = []
        @span_tokens.sort_by { |tok| self.class.read_attr(tok, :position_in_sentence).to_i }.each do |tok|
          text = (self.class.read_attr(tok, :text_digital_khatt) ||
                  self.class.read_attr(tok, :text_qpc_hafs) ||
                  self.class.read_attr(tok, :text_uthmani)).to_s
          key = word_key(tok)
          if key && words.last && words.last[0] == key
            words.last[1] << text
          else
            # dup: appending to the token's own string would rewrite its text
            # everywhere else it is shown.
            words << [key, text.dup]
          end
        end
        text = words.map(&:last).join(' ')
        text.empty? ? self.class.read_attr(@token, :constituent_text).to_s : text
      end

      def word_key(tok)
        return nil unless self.class.read_attr(tok, :token_type).to_s == 'surface'

        %i[chapter_number verse_number word_number].map { |k| self.class.read_attr(tok, k) }
      end
    end
  end
end
