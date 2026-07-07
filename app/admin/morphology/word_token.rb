# frozen_string_literal: true

ActiveAdmin.register Morphology::WordToken do
  menu parent: 'Morphology'
  actions :index, :show
  includes :sentence, :word

  filter :location_cont, label: 'Location'
  filter :token_type, as: :select, collection: -> { Morphology::WordToken.token_types }
  filter :pos_key, as: :select, collection: -> { Corpus::Morphology::PartOfSpeech.all.map(&:tag).sort }
  filter :segment_type, as: :select, collection: %w[Prefix Stem Suffix]
  filter :rel_label, as: :select, collection: -> { Morphology::WordToken.distinct.pluck(:rel_label).compact.sort }
  filter :nominal_case, as: :select, collection: %w[NOM ACC GEN]
  filter :verb_aspect, as: :select, collection: %w[PERF IMPF IMPV]
  filter :verb_form
  filter :special_group, as: :select, collection: %w[kana inna kada]
  filter :chapter_number
  filter :verse_number
  filter :sentence_id, as: :numeric

  index do
    id_column
    column :location do |token|
      token.location || token.token_type
    end
    column :text do |token|
      span token.text_qpc_hafs, class: 'qpc-hafs quran-text'
    end
    column :token_type
    column :pos_key
    column :segment_type
    column :rel_label do |token|
      token.rel_label_name
    end
    column :sentence do |token|
      token.sentence && link_to(token.sentence.sentence_number, [:cms, token.sentence])
    end
  end

  show do
    attributes_table title: 'Position' do
      row :sentence
      row :word
      row :morphology_word
      row :token_type
      row :location
      row :chapter_number
      row :verse_number
      row :word_number
      row :position_in_word
      row :position_in_sentence
      row :word_position_in_sentence
    end

    attributes_table title: 'Texts' do
      row :text_uthmani do |token|
        span token.text_uthmani, class: 'qpc-hafs quran-text'
      end
      row :text_qpc_hafs do |token|
        span token.text_qpc_hafs, class: 'qpc-hafs quran-text'
      end
      row :text_imlaai
      row :phonetic
      row :translation_en
    end

    attributes_table title: 'Morphology' do
      row :pos_key do |token|
        "#{token.pos_key} — #{token.pos_name}"
      end
      row :segment_type
      row :lemma
      row :lemma_name
      row :root
      row :root_name
      row :verb_form
      row :verb_aspect
      row :verb_mood
      row :verb_voice
      row :nominal_case
      row :nominal_state
      row :derived_noun_type
      row :special_group do |token|
        token.special_group && I18n.t("morphology.special_groups.#{token.special_group}")
      end
      row :prefix_type
      row :suffix_type
      row :pgn
      row :person
      row :gender
      row :number
      row :features
    end

    attributes_table title: 'Dependency' do
      row :rel_label do |token|
        token.rel_label_name
      end
      row :rel_governor
      row :ref_token_position
      row :head_token
      row :dependent_is_phrase
      row :head_is_phrase
    end

    attributes_table title: 'Constituency' do
      row :is_constituent
      row :constituent_span_start
      row :constituent_span_end
      row :constituent_text do |token|
        token.constituent_text && span(token.constituent_text, class: 'qpc-hafs quran-text')
      end
      row :constituent_label
    end

    attributes_table title: 'Source' do
      row :source_meta
    end
  end
end
