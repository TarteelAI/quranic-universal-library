module Morphology
  module Treebank
    class IrabLine
      PREFIX_KEYS = %w[
        A:EQ+ A:INTG+ Al+ bi+ f:CAUS+ f:CONJ+ f:REM+ f:RSLT+ f:SUP+ ha+ ka+
        l:EMPH+ l:IMPV+ l:P+ l:PRP+ sa+ ta+ w:CIRC+ w:COM+ w:CONJ+ w:P+ w:REM+
        w:SUP+ ya+
      ].freeze

      SUFFIX_KEYS = %w[VOC:m EMPH:n PRON l:P+].freeze
      VERB_ASPECT_KEYS = %w[PERF IMPF IMPV].freeze
      DERIVED_NOUN_KEYS = %w[ACT_PCPL PASS_PCPL VN].freeze
      NOMINAL_STATE_KEYS = %w[DEF INDEF].freeze
      VERB_VOICE_KEYS = %w[ACT PASS].freeze
      SPECIAL_GROUP_KEYS = ['SP:<in~', 'SP:kaAd', 'SP:kaAn'].freeze
      NUMBER_KEYS = %w[S D P].freeze
      GENDER_KEYS = %w[M F].freeze

      HIDDEN_TYPES = %w[implicit_pronoun elided].freeze

      ZWJ = "\u200D".freeze

      # predicate_token: the خبر pointing at this token, when it heads a
      # nominal sentence. phrase_head: the token's relation is told on the
      # phrase line of the constituent it heads (IrabPhraseLine), as NoorBayan
      # does, so this line leaves it out.
      def initialize(token, head_token:, translator:, locale: 'ar', predicate_token: nil, phrase_head: false)
        @token = token
        @head_token = head_token
        @translator = translator
        @locale = locale.to_s
        @predicate_token = predicate_token
        @phrase_head = phrase_head
      end

      # Same field order as NoorBayan's iirab.py.
      def fragments
        result = []
        result.concat(segment_fragments)
        result.concat(pos_fragments)
        result.concat(prefix_fragments)
        result.concat(suffix_fragments)
        result.concat(verb_aspect_fragments)
        result.concat(derived_noun_fragments)
        result.concat(nominal_state_fragments)
        result.concat(special_group_fragments)
        result.concat(verb_voice_fragments)
        result.concat(number_fragments)
        result.concat(gender_fragments)
        result.concat(verb_mood_word_fragments)
        result.concat(nominal_case_word_fragments)
        result.concat(lemma_fragments)
        result.concat(verb_form_fragments)
        result.concat(root_fragments)
        result.concat(dependency_fragments) unless @phrase_head
        result.concat(mubtada_fragments)
        result.concat(case_explanation_fragments)
        result
      end

      private

      def t(key, default: nil)
        @translator.call("morphology.irab.#{key}", locale: @locale, default: default)
      end

      def t_attr(key)
        self.class.read_attr(@token, key)
      end

      def head_attr(key)
        self.class.read_attr(@head_token, key)
      end

      # Tokens arrive either as AR records or as plain Hashes/Structs in tests.
      # A Struct raises NameError for a member it does not have, so an attribute
      # a given source simply does not carry reads as nil rather than blowing up.
      def self.read_attr(obj, key)
        return nil if obj.nil?
        return obj.public_send(key) if obj.respond_to?(key)
        return nil unless obj.respond_to?(:[])

        begin
          obj[key]
        rescue NameError, IndexError, TypeError
          nil
        end
      end

      def pos_color
        Morphology::Treebank::Colors.pos(t_attr(:pos_key).to_s)
      end

      def rel_color
        Morphology::Treebank::Colors.relation(t_attr(:rel_label).to_s)
      end

      def head_pos_color
        Morphology::Treebank::Colors.pos(head_attr(:pos_key).to_s)
      end

      def translate_pos(pos_key, locale: @locale)
        return '' if pos_key.to_s.strip.empty?
        @translator.call("morphology.pos_tags.#{pos_key.to_s.upcase}", locale: locale, default: pos_key.to_s)
      end

      def frag(text, color_class: 'black', quran_font: false, link_type: nil, link_key: nil)
        { text: text, color_class: color_class, quran_font: quran_font, link_type: link_type, link_key: link_key }
      end

      def guillemet_frags(value, lead_in:, color_class: 'black', quran_value: false, link_type: nil, link_key: nil)
        [
          frag(lead_in, color_class: 'black'),
          frag(value, color_class: color_class, quran_font: quran_value, link_type: link_type, link_key: link_key),
          frag('»', color_class: 'black')
        ]
      end

      # The segment this line describes, as iirab.py opens each line with it:
      # "بِ: حرف جر".
      def segment_fragments
        text = (t_attr(:text_digital_khatt) || t_attr(:text_qpc_hafs) || t_attr(:text_uthmani)).to_s
        return [] if text.strip.empty?

        [frag(text, color_class: pos_color, quran_font: true), frag(': ')]
      end

      def pos_fragments
        pos_key = t_attr(:pos_key).to_s
        return [] if pos_key.empty?
        label = translate_pos(pos_key)
        return [] if label.empty?
        [frag(label, color_class: pos_color)]
      end

      def prefix_fragments
        raw = t_attr(:prefix_type).to_s
        return [] unless PREFIX_KEYS.include?(raw)
        guillemet_frags(t("prefix.#{raw}", default: raw), lead_in: ' «')
      end

      def suffix_fragments
        raw = t_attr(:suffix_type).to_s
        return [] unless SUFFIX_KEYS.include?(raw)
        guillemet_frags(t("suffix.#{raw}", default: raw), lead_in: ' «')
      end

      def verb_aspect_fragments
        raw = t_attr(:verb_aspect).to_s
        return [] unless VERB_ASPECT_KEYS.include?(raw)
        guillemet_frags(t("verb_aspect.#{raw}", default: raw), lead_in: ' «')
      end

      def derived_noun_fragments
        raw = t_attr(:derived_noun_type).to_s
        return [] unless DERIVED_NOUN_KEYS.include?(raw)
        guillemet_frags(t("derived_noun.#{raw}", default: raw), lead_in: ' «')
      end

      def nominal_state_fragments
        raw = t_attr(:nominal_state).to_s
        return [] unless NOMINAL_STATE_KEYS.include?(raw)
        [frag(t("nominal_state.#{raw}", default: raw))]
      end

      def verb_voice_fragments
        raw = t_attr(:verb_voice).to_s
        return [] unless VERB_VOICE_KEYS.include?(raw)
        [frag(t("verb_voice.#{raw}", default: raw))]
      end

      def special_group_fragments
        raw = t_attr(:special_group).to_s
        return [] unless SPECIAL_GROUP_KEYS.include?(raw)
        [frag(t("special_group.#{raw}", default: raw))]
      end

      def number_fragments
        raw = t_attr(:number).to_s
        return [] unless NUMBER_KEYS.include?(raw)
        [frag(t("number.#{raw}", default: raw))]
      end

      def gender_fragments
        raw = t_attr(:gender).to_s
        return [] unless GENDER_KEYS.include?(raw)
        [frag(t("gender.#{raw}", default: raw))]
      end

      def verb_mood_word_fragments
        raw = verb_mood
        return [] if raw.empty?

        word = t("verb_mood_word.#{raw}", default: '')
        word.to_s.empty? ? [] : [frag(word)]
      end

      def nominal_case_word_fragments
        raw = t_attr(:nominal_case).to_s
        return [] if raw.empty?

        word = t("nominal_case_word.#{raw}", default: '')
        word.to_s.empty? ? [] : [frag(word)]
      end

      # Stored as JUS/SUBJ; older fixtures carry NoorBayan's MOOD: prefix.
      def verb_mood
        t_attr(:verb_mood).to_s.delete_prefix('MOOD:')
      end

      def lemma_fragments
        val = t_attr(:lemma_name)
        return [] if val.to_s.strip.empty?
        key = lemma_link_key
        guillemet_frags(val.to_s, lead_in: t('lemma_intro', default: ''), quran_value: true, link_type: (key ? :lemma : nil), link_key: key)
      end

      def root_fragments
        val = t_attr(:root_name)
        return [] if val.to_s.strip.empty?
        key = root_link_key
        guillemet_frags(val.to_s, lead_in: t('root_intro', default: ''), quran_value: true, link_type: (key ? :root : nil), link_key: key)
      end

      def lemma_link_key
        lemma = assoc_attr(:lemma)
        return nil unless lemma.respond_to?(:text_clean)
        lemma.text_clean.presence
      end

      def root_link_key
        root = assoc_attr(:root)
        return nil unless root.respond_to?(:arabic_trilateral)
        root.arabic_trilateral.presence
      end

      def assoc_attr(key)
        if @token.respond_to?(key)
          @token.public_send(key)
        elsif @token.is_a?(Hash)
          @token[key]
        end
      end

      def verb_form_fragments
        val = t_attr(:verb_form)
        return [] if val.to_s.strip.empty?
        guillemet_frags(val.to_s, lead_in: t('verb_form_intro', default: ''))
      end

      def dependency_fragments
        rel = t_attr(:rel_label).to_s
        return [] if rel.empty?
        return [] if @head_token.nil?
        return [] if %w[root nonrel].include?(rel)

        result = []
        result << frag(t('dep_intro', default: ''), color_class: 'black')
        result << frag(relation_label(rel), color_class: rel_color)

        head_pos_key = head_attr(:pos_key).to_s
        head_pos = translate_pos(head_pos_key)
        head_tok_type = head_attr(:token_type).to_s
        head_text = (head_attr(:text_digital_khatt) || head_attr(:text_qpc_hafs)).to_s

        result << frag(head_link(rel, head_pos), color_class: 'black')
        result << frag(head_pos_label(head_pos), color_class: head_pos_color)

        if HIDDEN_TYPES.include?(head_tok_type)
          result << frag(elided_word(head_pos_key), color_class: 'black')
        else
          # Space stays outside the RTL-isolated bracket run so it separates
          # the reference from the preceding word in LTR lines too.
          result << frag(' ')
          result << head_reference_fragment(head_text)
        end

        result
      end

      def relation_label(rel)
        Morphology::Treebank::RelationLabel.call(
          rel, t_attr(:rel_governor), locale: @locale, translator: @translator
        )
      end

      # Arabic joins the relation to the head with the preposition the
      # relation takes, plus the article on a one-word head: "مجرور بحرف
      # الجر", "معطوف على الفعل", "صفة للاسم". A two-word head ("حرف جر") is
      # an iḍāfa, so the article moves to its second word (head_pos_label).
      # Locales without connectors keep their single dep_to.
      def head_link(rel, head_pos)
        connector = t("dep_connector.#{rel}", default: '').presence ||
                    t('dep_connector.default', default: '').presence
        return t('dep_to', default: '') if connector.nil?

        lead = if head_pos.split(' ').length == 1
                 connector == 'ل' ? 'لل' : "#{connector}ال"
               else
                 connector
               end
        lead.end_with?(' ') ? " #{lead}" : " #{lead}#{ZWJ}"
      end

      # iirab.py: a token that a خبر points at is the مبتدأ of a nominal
      # sentence, and says so when the predicate is elided.
      def mubtada_fragments
        return [] unless @predicate_token
        return [] unless t_attr(:rel_label).to_s == 'root'

        pred_type = self.class.read_attr(@predicate_token, :token_type).to_s
        key = HIDDEN_TYPES.include?(pred_type) ? 'mubtada_elided_pred' : 'mubtada'
        text = t(key, default: '')
        text.to_s.empty? ? [] : [frag(text)]
      end

      def head_pos_label(head_pos)
        return head_pos unless @locale == 'ar'
        parts = head_pos.split(' ')
        parts.length == 2 ? parts[0] + t('def_infix', default: '') + parts[1] : parts[0]
      end

      def elided_word(head_pos_key)
        feminine = translate_pos(head_pos_key, locale: 'ar').to_s[-1] == 'ة'
        t(feminine ? 'elided_f' : 'elided_m', default: '')
      end

      def head_reference_fragment(head_text)
        {
          wrapper_class: 'treebank-quran-text',
          children: [
            { text: '﴿', color_class: 'black' },
            { text: head_text, color_class: 'green' },
            { text: '﴾', color_class: 'black' }
          ]
        }
      end

      def case_explanation_fragments
        nominal_case = t_attr(:nominal_case).to_s
        return [] if nominal_case.empty? && verb_mood.empty?

        ending = final_harakah

        p = nil

        unless verb_mood.empty?
          if verb_mood == 'JUS' && ending == 'ْ'
            p = frag(t('case.jussive_sukun', default: ''), color_class: 'purple')
          elsif verb_mood == 'SUBJ' && ending == 'َ'
            p = frag(t('case.subjunctive_fatha', default: ''), color_class: 'green')
          end
        end

        unless nominal_case.empty?
          if nominal_case == 'NOM' && ending == 'ُ'
            p = frag(t('case.nominative_damma', default: ''), color_class: 'red')
          elsif nominal_case == 'ACC' && ending == 'َ'
            p = frag(t('case.accusative_fatha', default: ''), color_class: 'green')
          elsif nominal_case == 'GEN' && ending == 'ِ'
            p = frag(t('case.genitive_kasra', default: ''), color_class: 'red')
          end
        end

        p ? [p] : []
      end

      # Short vowels that can carry a case ending, plus the mushaf's sukun
      # (U+06E1) folded onto the plain one.
      CASE_MARKS = /[َُِْۡ]/

      # The i'rab only names a case ending when the script actually shows it.
      # Read it off the vocalised text rather than NoorBayan's `text_uthmani`,
      # which carries no tashkeel at all for chapters 9-58, and scan backwards
      # for the last vowel so a trailing waqf sign does not hide it.
      def final_harakah
        text = (t_attr(:text_qpc_hafs) || t_attr(:text_uthmani)).to_s
        mark = text.reverse.chars.find { |c| c =~ CASE_MARKS }
        mark == "ۡ" ? "ْ" : mark
      end
    end
  end
end
