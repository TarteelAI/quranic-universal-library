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

      def initialize(token, head_token:, translator:, locale: 'ar')
        @token = token
        @head_token = head_token
        @translator = translator
        @locale = locale.to_s
      end

      def fragments
        result = []
        result.concat(pos_fragments)
        result.concat(prefix_fragments)
        result.concat(suffix_fragments)
        result.concat(verb_aspect_fragments)
        result.concat(derived_noun_fragments)
        result.concat(nominal_state_fragments)
        result.concat(verb_voice_fragments)
        result.concat(special_group_fragments)
        result.concat(number_fragments)
        result.concat(gender_fragments)
        result.concat(lemma_fragments)
        result.concat(root_fragments)
        result.concat(verb_form_fragments)
        result.concat(dependency_fragments)
        result.concat(case_explanation_fragments)
        result
      end

      private

      def t(key, default: nil)
        @translator.call("morphology.irab.#{key}", locale: @locale, default: default)
      end

      def t_attr(key)
        if @token.respond_to?(key)
          @token.public_send(key)
        elsif @token.respond_to?(:[])
          @token[key]
        end
      end

      def head_attr(key)
        return nil unless @head_token
        if @head_token.respond_to?(key)
          @head_token.public_send(key)
        elsif @head_token.respond_to?(:[])
          @head_token[key]
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

      def translate_relation(rel_label)
        return '' if rel_label.to_s.strip.empty?
        @translator.call("morphology.edge_relations.#{rel_label}", locale: @locale, default: rel_label.to_s)
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
        result << frag(translate_relation(rel), color_class: rel_color)

        head_pos_key = head_attr(:pos_key).to_s
        head_pos = translate_pos(head_pos_key)
        head_tok_type = head_attr(:token_type).to_s
        head_text = head_attr(:text_qpc_hafs).to_s

        result << frag(t('dep_to', default: ''), color_class: 'black')
        result << frag(head_pos_label(head_pos), color_class: head_pos_color)

        if HIDDEN_TYPES.include?(head_tok_type)
          result << frag(elided_word(head_pos_key), color_class: 'black')
        else
          result << head_reference_fragment(head_text)
        end

        result
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
          wrapper_class: 'qpc-hafs',
          children: [
            { text: ' ﴿', color_class: 'black' },
            { text: head_text, color_class: 'green' },
            { text: '﴾', color_class: 'black' }
          ]
        }
      end

      def case_explanation_fragments
        nominal_case = t_attr(:nominal_case).to_s
        verb_mood = t_attr(:verb_mood).to_s
        return [] if nominal_case.empty? && verb_mood.empty?

        last_char = t_attr(:text_uthmani).to_s[-1]

        p = nil

        unless verb_mood.empty?
          if verb_mood == 'MOOD:JUS' && last_char == 'ْ'
            p = frag(t('case.jussive_sukun', default: ''), color_class: 'purple')
          elsif verb_mood == 'MOOD:SUBJ' && last_char == 'َ'
            p = frag(t('case.subjunctive_fatha', default: ''), color_class: 'green')
          end
        end

        unless nominal_case.empty?
          if nominal_case == 'NOM' && last_char == 'ُ'
            p = frag(t('case.nominative_damma', default: ''), color_class: 'red')
          elsif nominal_case == 'ACC' && last_char == 'َ'
            p = frag(t('case.accusative_fatha', default: ''), color_class: 'green')
          elsif nominal_case == 'GEN' && last_char == 'ِ'
            p = frag(t('case.genitive_kasra', default: ''), color_class: 'red')
          end
        end

        p ? [p] : []
      end
    end
  end
end
