module Morphology
  module Treebank
    class IrabLine
      PREFIX_LABELS = {
        'A:EQ+'   => 'همزة تسوية',
        'A:INTG+' => 'همزة استفهام',
        'Al+'     => 'ال التعريف',
        'bi+'     => 'باء الجر',
        'f:CAUS+' => 'فاء السببية',
        'f:CONJ+' => 'فاء العطف',
        'f:REM+'  => 'فاء الإستئناف',
        'f:RSLT+' => 'فاء الشرط',
        'f:SUP+'  => 'فاء الزائدة',
        'ha+'     => 'هاء النداء',
        'ka+'     => 'كاف الجر',
        'l:EMPH+' => 'لام التوكيد',
        'l:IMPV+' => 'لام الأمر',
        'l:P+'    => 'لام الجر',
        'l:PRP+'  => 'لام التعليل',
        'sa+'     => 'سين المستقبل',
        'ta+'     => 'تاء النداء',
        'w:CIRC+' => 'واو الظرفية',
        'w:COM+'  => 'واو المعية',
        'w:CONJ+' => 'واو العطف',
        'w:P+'    => 'واو الجر',
        'w:REM+'  => 'واو الإستئناف',
        'w:SUP+'  => 'واو الزائدة',
        'ya+'     => 'ياء النداء'
      }.freeze

      SUFFIX_LABELS = {
        'VOC:m'  => 'ميم النداء',
        'EMPH:n' => 'نون التوكيد',
        'PRON'   => 'ضمير متصل',
        'l:P+'   => 'لام الجر'
      }.freeze

      VERB_ASPECT_LABELS = {
        'PERF' => 'فعل ماضي',
        'IMPF' => 'فعل مضارع',
        'IMPV' => 'فعل أمر'
      }.freeze

      NOMINAL_STATE_LABELS = {
        'DEF'   => 'معرفة',
        'INDEF' => 'نكرة'
      }.freeze

      VERB_MOOD_LABELS = {
        'MOOD:IND'  => 'مرفوع',
        'MOOD:JUS'  => 'مجزوم',
        'MOOD:SUBJ' => 'منصوب'
      }.freeze

      SPECIAL_GROUP_LABELS = {
        'SP:<in~' => 'من اخوات ان',
        'SP:kaAd' => 'من اخوات كاد',
        'SP:kaAn' => 'من اخوات ان'
      }.freeze

      NOMINAL_CASE_LABELS = {
        'NOM' => 'مرفوع',
        'ACC' => 'منصوب',
        'GEN' => 'مجرور'
      }.freeze

      DERIVED_NOUN_LABELS = {
        'ACT_PCPL' => 'اسم فاعل',
        'PASS_PCPL' => 'اسم مفعول',
        'VN' => 'مصدر'
      }.freeze

      VERB_VOICE_LABELS = {
        'ACT'  => 'مبني للمعلوم',
        'PASS' => 'مبني للمجهول'
      }.freeze

      NUMBER_LABELS = {
        'S' => 'مفرد',
        'D' => 'مثنى',
        'P' => 'جمع'
      }.freeze

      GENDER_LABELS = {
        'M' => 'مذكر',
        'F' => 'مؤنث'
      }.freeze

      HIDDEN_TYPES = %w[implicit_pronoun elided].freeze

      def initialize(token, head_token:, translator:)
        @token = token
        @head_token = head_token
        @translator = translator
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
        result.concat(nominal_case_raw_fragments)
        result.concat(verb_mood_raw_fragments)
        result.concat(lemma_fragments)
        result.concat(root_fragments)
        result.concat(verb_form_fragments)
        result.concat(dependency_fragments)
        result.concat(case_explanation_fragments)
        result
      end

      private

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

      def translate_pos(pos_key)
        return '' if pos_key.to_s.strip.empty?
        @translator.call("morphology.pos_tags.#{pos_key.to_s.upcase}", locale: 'ar', default: pos_key.to_s)
      end

      def translate_relation(rel_label)
        return '' if rel_label.to_s.strip.empty?
        @translator.call("morphology.edge_relations.#{rel_label}", locale: 'ar', default: rel_label.to_s)
      end

      def frag(text, color_class: 'black', arabic_font: true)
        { text: text, color_class: color_class, arabic_font: arabic_font }
      end

      def guillemet_frags(value, lead_in:, color_class: 'black')
        [
          frag(lead_in, color_class: 'black'),
          frag(value, color_class: color_class),
          frag('»', color_class: 'black')
        ]
      end

      def plain_frag(prefix_text, value, color_class: 'black')
        [frag(prefix_text + value, color_class: color_class)]
      end

      def pos_fragments
        pos_key = t_attr(:pos_key).to_s
        return [] if pos_key.empty?
        label = translate_pos(pos_key)
        return [] if label.empty?
        [frag(label, color_class: pos_color)]
      end

      def prefix_fragments
        val = PREFIX_LABELS[t_attr(:prefix_type).to_s]
        return [] unless val
        guillemet_frags(val, lead_in: ' «')
      end

      def suffix_fragments
        val = SUFFIX_LABELS[t_attr(:suffix_type).to_s]
        return [] unless val
        guillemet_frags(val, lead_in: ' «')
      end

      def verb_aspect_fragments
        val = VERB_ASPECT_LABELS[t_attr(:verb_aspect).to_s]
        return [] unless val
        guillemet_frags(val, lead_in: ' «')
      end

      def derived_noun_fragments
        val = DERIVED_NOUN_LABELS[t_attr(:derived_noun_type).to_s]
        return [] unless val
        guillemet_frags(val, lead_in: ' «')
      end

      def nominal_state_fragments
        val = NOMINAL_STATE_LABELS[t_attr(:nominal_state).to_s]
        return [] unless val
        [frag(' ' + val)]
      end

      def verb_voice_fragments
        val = VERB_VOICE_LABELS[t_attr(:verb_voice).to_s]
        return [] unless val
        [frag(' ' + val)]
      end

      def special_group_fragments
        val = SPECIAL_GROUP_LABELS[t_attr(:special_group).to_s]
        return [] unless val
        [frag(' ' + val)]
      end

      def number_fragments
        val = NUMBER_LABELS[t_attr(:number).to_s]
        return [] unless val
        [frag(' لل‍' + val)]
      end

      def gender_fragments
        val = GENDER_LABELS[t_attr(:gender).to_s]
        return [] unless val
        [frag(' ال‍' + val)]
      end

      def nominal_case_raw_fragments
        []
      end

      def verb_mood_raw_fragments
        []
      end

      def lemma_fragments
        val = t_attr(:lemma_name)
        return [] if val.to_s.strip.empty?
        guillemet_frags(val.to_s, lead_in: '، اللما له «')
      end

      def root_fragments
        val = t_attr(:root_name)
        return [] if val.to_s.strip.empty?
        guillemet_frags(val.to_s, lead_in: '، الجذر له «')
      end

      def verb_form_fragments
        val = t_attr(:verb_form)
        return [] if val.to_s.strip.empty?
        guillemet_frags(val.to_s, lead_in: '، النمط له «')
      end

      def dependency_fragments
        rel = t_attr(:rel_label).to_s
        return [] if rel.empty?
        return [] if @head_token.nil?
        return [] if %w[root nonrel].include?(rel)

        rel_label_ar = translate_relation(rel)
        result = []
        result << frag('. وهو ', color_class: 'black')
        result << frag(rel_label_ar, color_class: rel_color)

        head_pos_key = head_attr(:pos_key).to_s
        head_pos_ar = translate_pos(head_pos_key)
        head_tok_type = head_attr(:token_type).to_s
        head_text = head_attr(:text_qpc_hafs).to_s

        rp_parts = head_pos_ar.split(' ')
        rp_label = rp_parts.length == 2 ? rp_parts[0] + ' ال‍' + rp_parts[1] : rp_parts[0]
        result << frag(' لل‍', color_class: 'black')
        result << frag(rp_label, color_class: head_pos_color)

        if HIDDEN_TYPES.include?(head_tok_type)
          hidden = head_pos_ar.length >= 1 && head_pos_ar[-1] == 'ة' ? 'المحذوفة' : 'المحذوف'
          result << frag(' ', color_class: 'black')
          result << frag(hidden, color_class: 'black')
          result << frag('.', color_class: 'black')
        else
          result << frag(' ﴿', color_class: 'black')
          result << frag(head_text, color_class: 'green')
          result << frag('﴾', color_class: 'black')
        end

        result
      end

      def case_explanation_fragments
        nominal_case = t_attr(:nominal_case).to_s
        verb_mood = t_attr(:verb_mood).to_s
        return [] if nominal_case.empty? && verb_mood.empty?

        uthmani = t_attr(:text_uthmani).to_s
        last_char = uthmani[-1]

        p = nil

        if !verb_mood.empty?
          vm_ar = VERB_MOOD_LABELS[verb_mood]
          if vm_ar == 'مجزوم' && last_char == 'ْ'
            p = frag(vm_ar + ' بالسكون لانه معتل الاخر.', color_class: 'purple')
          elsif vm_ar == 'منصوب' && last_char == 'َ'
            p = frag(vm_ar + ' وعلامة نصبه الفتحة الظاهرة على اخره.', color_class: 'green')
          end
        end

        if !nominal_case.empty?
          nc_ar = NOMINAL_CASE_LABELS[nominal_case]
          if nc_ar == 'مرفوع' && last_char == 'ُ'
            p = frag('مرفوع وعلامة رفعه الضمة الظاهرة على اخره.', color_class: 'red')
          elsif nc_ar == 'منصوب' && last_char == 'َ'
            p = frag('منصوب وعلامة نصبه الفتحة الظاهرة على اخره.', color_class: 'green')
          elsif nc_ar == 'مجرور' && last_char == 'ِ'
            p = frag('مجرور وعلامة جره الكسره الظاهرة على اخره.', color_class: 'red')
          end
        end

        p ? [p] : []
      end
    end
  end
end
