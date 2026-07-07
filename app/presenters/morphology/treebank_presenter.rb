module Morphology
  class TreebankPresenter
    def initialize(verse:, sentences:, locale:, translator: nil, chapter: nil)
      @verse = verse
      @sentences = sentences
      @locale = locale.to_s
      @translator = translator || method(:default_translate)
      @chapter = chapter || (verse.respond_to?(:chapter) ? verse.chapter : nil)
    end

    def to_json_payload
      {
        verseKey: verse_key,
        sentences: @sentences.map { |s| sentence_payload(s) }
      }
    end

    private

    def verse_key
      if @verse.respond_to?(:verse_key)
        @verse.verse_key
      else
        "#{@verse.chapter_id}:#{@verse.verse_number}"
      end
    end

    def sentence_payload(sentence)
      tokens = sentence.respond_to?(:word_tokens) ? sentence.word_tokens.to_a : Array(sentence[:tokens])
      level_data = build_level_data(tokens)

      {
        sentenceNumber: sentence.respond_to?(:sentence_number) ? sentence.sentence_number : sentence[:sentence_number],
        verseRange: sentence_verse_range(sentence),
        banner: banner_payload(sentence),
        tokens: tokens_payload(tokens),
        edges: edges_payload(tokens),
        phraseNodes: phrase_nodes_payload(level_data[:phrase_nodes]),
        locale: @locale
      }
    end

    def build_level_data(tokens)
      token_hashes = tokens.map { |t| token_to_builder_hash(t) }
      Morphology::Treebank::LevelBuilder.new(token_hashes).build
    end

    def token_to_builder_hash(t)
      {
        position:          t_attr(t, :position_in_sentence),
        is_constituent:    t_attr(t, :is_constituent) || 0,
        span_start:        t_attr(t, :constituent_span_start),
        span_end:          t_attr(t, :constituent_span_end),
        constituent_label: t_attr(t, :constituent_label),
        constituent_text:  t_attr(t, :constituent_text),
        rel_label:         t_attr(t, :rel_label),
        ref_position:      t_attr(t, :ref_token_position),
        dependent_is_phrase: t_attr(t, :dependent_is_phrase) || false,
        head_is_phrase:    t_attr(t, :head_is_phrase) || false
      }
    end

    def tokens_payload(tokens)
      tokens.map { |t| token_payload(t) }
    end

    def token_payload(t)
      pos_key     = t_attr(t, :pos_key).to_s
      tok_type    = token_type_string(t)
      arabic      = t_attr(t, :text_qpc_hafs) || t_attr(t, :text_uthmani)
      ch          = t_attr(t, :chapter_number)
      v           = t_attr(t, :verse_number)
      w           = t_attr(t, :word_number)

      {
        position:   t_attr(t, :position_in_sentence),
        location:   t_attr(t, :location),
        arabic:     arabic,
        posKey:     pos_key,
        posLabel:   translate_pos(pos_key),
        colorClass: Morphology::Treebank::Colors.pos(pos_key),
        tokenType:  tok_type,
        wordUrl:    surface_token?(tok_type) ? "/morphology/word?location=#{ch}:#{v}:#{w}" : nil
      }
    end

    def edges_payload(tokens)
      head_position_map = build_head_position_map(tokens)

      tokens.filter_map do |t|
        head_token_id = t_attr(t, :head_token_id)
        next if head_token_id.nil?

        from_pos = t_attr(t, :position_in_sentence)
        to_pos   = head_position_map[head_token_id]
        next if to_pos.nil?
        next if from_pos == to_pos

        rel = t_attr(t, :rel_label).to_s
        label = build_rel_label(t)

        {
          from:          from_pos,
          to:            to_pos,
          relation:      rel,
          label:         label,
          colorClass:    Morphology::Treebank::Colors.relation(rel),
          direction:     from_pos > to_pos ? 'left' : 'right',
          fromIsPhrase:  t_attr(t, :dependent_is_phrase) || false,
          toIsPhrase:    t_attr(t, :head_is_phrase) || false
        }
      end
    end

    def build_head_position_map(tokens)
      tokens.each_with_object({}) do |t, h|
        id = t_attr(t, :id)
        pos = t_attr(t, :position_in_sentence)
        h[id] = pos if !id.nil? && !pos.nil?
      end
    end

    def phrase_nodes_payload(phrase_nodes)
      phrase_nodes.map do |node|
        label_key = node[:label].to_s
        {
          level:        node[:level],
          span:         node[:span],
          centroid:     node[:centroid],
          headPosition: node[:head_position],
          labelKey:     label_key,
          label:        translate_relation(label_key),
          text:         node[:text]
        }
      end
    end

    def banner_payload(sentence)
      tokens = sentence.respond_to?(:word_tokens) ? sentence.word_tokens.to_a : Array(sentence[:tokens])
      inner = build_banner_text_from_tokens(tokens)
      text = "\u{FD3F}#{inner}\u{FD3E}"
      {
        text:      text,
        reference: build_reference(sentence)
      }
    end

    def build_banner_text_from_tokens(tokens)
      sorted = tokens.sort_by { |t| t_attr(t, :position_in_sentence).to_i }
      word_groups = []
      sorted.each do |t|
        wn = t_attr(t, :word_number)
        tok_type = token_type_string(t)
        arabic = t_attr(t, :text_qpc_hafs) || t_attr(t, :text_uthmani) || ''
        if wn.nil? || tok_type != 'surface'
          word_groups << [arabic]
        else
          existing = word_groups.find { |g| g.first == "__wn_#{wn}" }
          if existing
            existing << arabic
          else
            word_groups << ["__wn_#{wn}", arabic]
          end
        end
      end
      word_groups.map { |g| g.first.start_with?('__wn_') ? g[1..].join('') : g.join('') }.join(' ')
    end

    def build_reference(sentence)
      first_v = sentence_first_verse(sentence)
      last_v  = sentence_last_verse(sentence)

      chapter_name = chapter_name_for_locale
      first_num = verse_number(first_v)
      last_num  = verse_number(last_v)

      if @locale == 'ar'
        chapter_part = "سورة #{chapter_name}."
        if first_num == last_num
          "[#{chapter_part} الآية #{first_num}]"
        else
          "[#{chapter_part} الآيات #{first_num}-#{last_num}]"
        end
      else
        chapter_part = "Surah #{chapter_name}"
        if first_num == last_num
          "[#{chapter_part}, Ayah #{first_num}]"
        else
          "[#{chapter_part}, Ayat #{first_num}-#{last_num}]"
        end
      end
    end

    def chapter_name_for_locale
      return '' unless @chapter

      if @locale == 'ar'
        @chapter.respond_to?(:name_arabic) ? @chapter.name_arabic.to_s : @chapter.to_s
      else
        @chapter.respond_to?(:name_simple) ? @chapter.name_simple.to_s : @chapter.to_s
      end
    end

    def sentence_first_verse(sentence)
      if sentence.respond_to?(:first_verse)
        sentence.first_verse
      else
        sentence
      end
    end

    def sentence_last_verse(sentence)
      if sentence.respond_to?(:last_verse)
        sentence.last_verse
      else
        sentence
      end
    end

    def sentence_verse_range(sentence)
      if sentence.respond_to?(:verse_range)
        sentence.verse_range
      elsif sentence.respond_to?(:first_verse) && sentence.respond_to?(:last_verse)
        fv = sentence.first_verse
        lv = sentence.last_verse
        fv_key = fv.respond_to?(:verse_key) ? fv.verse_key : "#{t_attr(fv, :chapter_id)}:#{verse_number(fv)}"
        lv_key = lv.respond_to?(:verse_key) ? lv.verse_key : "#{t_attr(lv, :chapter_id)}:#{verse_number(lv)}"
        fv_key == lv_key ? fv_key : "#{fv_key} - #{lv_key}"
      else
        verse_key
      end
    end

    def verse_number(verse_obj)
      return 0 unless verse_obj

      if verse_obj.respond_to?(:verse_number)
        verse_obj.verse_number
      elsif verse_obj.respond_to?(:[])
        verse_obj[:verse_number]
      else
        0
      end
    end

    def token_type_string(t)
      val = t_attr(t, :token_type)
      return val.to_s if val.is_a?(String) || val.is_a?(Symbol)

      case val.to_i
      when 0 then 'surface'
      when 1 then 'implicit_pronoun'
      when 2 then 'elided'
      else 'surface'
      end
    end

    def surface_token?(tok_type)
      tok_type.to_s == 'surface'
    end

    def build_rel_label(t)
      rel = t_attr(t, :rel_label).to_s
      governor = t_attr(t, :rel_governor)

      base = translate_relation(rel)
      [base, governor].compact.reject { |s| s.to_s.strip.empty? }.join(' ')
    end

    def translate_pos(pos_key)
      return '' if pos_key.to_s.empty?

      @translator.call("morphology.pos_tags.#{pos_key.to_s.upcase}", locale: @locale, default: pos_key)
    end

    def translate_relation(rel_label)
      return '' if rel_label.to_s.empty?

      @translator.call("morphology.edge_relations.#{rel_label}", locale: @locale, default: rel_label)
    end

    def t_attr(obj, key)
      if obj.respond_to?(key)
        obj.public_send(key)
      elsif obj.respond_to?(:[])
        obj[key]
      end
    end

    def default_translate(key, locale:, default:)
      I18n.t(key, locale: locale, default: default)
    end
  end
end
