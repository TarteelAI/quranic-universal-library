module Morphology
  module NoorBayan
    class Row
      PLACEHOLDERS = ['_', 'ـ', '-', ''].freeze
      ELIDED_TEXT = '(*)'.freeze
      REL_WITH_GOVERNOR = /\A(\w+)\s*<<(.+)>>\z/

      SEGMENT_TYPES = { 'STEM' => 'Stem', 'PREFIX' => 'Prefix', 'SUFFIX' => 'Suffix' }.freeze
      DERIVED_NOUN_TYPES = { 'ACT_PCPL' => 'ACT PCPL', 'PASS_PCPL' => 'PASS PCPL', 'VN' => 'VN' }.freeze
      SPECIAL_GROUPS = { 'SP:kaAn' => 'kana', 'SP:<in~' => 'inna', 'SP:kaAd' => 'kada' }.freeze

      def initialize(data)
        @data = data
      end

      def token_type
        return 'elided' if raw('uthmani_token') == ELIDED_TEXT
        return 'implicit_pronoun' if raw('word_id').to_i.zero?

        'surface'
      end

      def sentence_number
        raw('sentence_id').to_i
      end

      def word_location
        return unless token_type == 'surface'

        "#{raw('chapter_id')}:#{raw('verse_id')}:#{raw('word_id')}"
      end

      def lemma_ar
        value('lemma_ar')
      end

      def root_ar
        value('root_ar')
      end

      def attributes
        @attributes ||= {
          token_type: token_type,
          location: location,
          chapter_number: raw('chapter_id').to_i,
          verse_number: raw('verse_id').to_i,
          word_number: token_type == 'surface' ? raw('word_id').to_i : nil,
          position_in_word: raw('tok_id').to_i,
          position_in_sentence: raw('token_id').to_i,
          word_position_in_sentence: raw('sentence_word').to_i,
          text_uthmani: value('uthmani_token'),
          text_qpc_hafs: to_qpc_hafs(value('uthmani_token')),
          text_imlaai: value('imlaai_token'),
          phonetic: value('phonetic'),
          translation_en: value('trans'),
          pos_key: pos_key,
          segment_type: mapped_value('segment', SEGMENT_TYPES),
          lemma_name: lemma_ar,
          root_name: root_ar,
          verb_form: parsed_tag(value('verb_form')&.delete('()'), Corpus::Morphology::FormType),
          verb_aspect: parsed_tag(value('verb_aspect'), Corpus::Morphology::AspectType),
          verb_mood: parsed_tag(value('verb_mood')&.delete_prefix('MOOD:'), Corpus::Morphology::MoodType),
          verb_voice: parsed_tag(value('verb_voice'), Corpus::Morphology::VoiceType),
          nominal_case: parsed_tag(value('nominal_case'), Corpus::Morphology::CaseType),
          nominal_state: parsed_tag(value('nominal_state'), Corpus::Morphology::StateType),
          derived_noun_type: mapped_value('derived_nouns', DERIVED_NOUN_TYPES),
          special_group: mapped_value('special_group', SPECIAL_GROUPS),
          prefix_type: value('prefix'),
          suffix_type: value('suffix'),
          pgn: value('pgn'),
          person: parsed_tag(value('person'), Corpus::Morphology::PersonType),
          gender: parsed_tag(value('gender'), Corpus::Morphology::GenderType),
          number: parsed_tag(value('number'), Corpus::Morphology::NumberType),
          features: value('features'),
          rel_label: rel_label,
          rel_governor: rel_governor,
          ref_token_position: value('ref_token_id')&.to_i,
          head_token_id: nil,
          dependent_is_phrase: raw('depend_rel') == '1',
          head_is_phrase: raw('head_rel') == '1',
          is_constituent: raw('is_constituent').to_i,
          constituent_span_start: constituent_span&.first,
          constituent_span_end: constituent_span&.last,
          constituent_text: value('constituents'),
          constituent_label: value('constituent_label') || value('constituent_label_en'),
          source_meta: source_meta
        }
      end

      private

      def raw(key)
        @data[key]
      end

      def value(key)
        v = raw(key)
        PLACEHOLDERS.include?(v.to_s.strip) ? nil : v
      end

      def mapped_value(key, map)
        v = value(key)
        return if v.nil?

        map.fetch(v) { raise ArgumentError, "Unknown #{key} value #{v.inspect}" }
      end

      def pos_key
        v = value('pos')
        return if v.nil?

        Corpus::Morphology::PartOfSpeech.parse(v).tag
      end

      def location
        value('location')&.delete('()')
      end

      def rel_parts
        @rel_parts ||= begin
          label = value('rel_label')
          if label.nil?
            []
          elsif (match = label.match(REL_WITH_GOVERNOR))
            governor = Governors::MAP.fetch(match[2]) do
              raise ArgumentError, "Unknown governor #{match[2].inspect} in #{label.inspect}"
            end
            [match[1].downcase, governor]
          else
            [label.downcase, nil]
          end
        end
      end

      def rel_label
        rel_parts[0]
      end

      def rel_governor
        rel_parts[1]
      end

      def constituent_span
        @constituent_span ||= value('constituents_loc')&.scan(/\d+/)&.map(&:to_i)
      end

      def to_qpc_hafs(text)
        text&.gsub('ْ', 'ۡ')&.gsub('۟', 'ْ')
      end

      def parsed_tag(value, klass)
        return if value.nil?

        klass.parse(value).tag
      end

      def source_meta
        {
          fid: value('FID'),
          loc1: value('loc1'),
          re_uthmani: value('re_uthmani'),
          rpos: value('rpos'),
          buckwalter: value('uthmani_unicode'),
          lemma_bw: value('lemma'),
          root_bw: value('root'),
          rel_label_raw: value('rel_label'),
          rel_label_ar: value('rel_label_ar'),
          constituent_label_en: value('constituent_label_en')
        }.compact
      end
    end
  end
end
