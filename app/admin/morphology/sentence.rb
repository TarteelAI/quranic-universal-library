# frozen_string_literal: true

ActiveAdmin.register Morphology::Sentence do
  menu parent: 'Morphology'
  actions :index, :show
  includes :first_verse, :last_verse

  filter :sentence_number
  filter :chapter_id, as: :numeric
  filter :verses_count
  filter :tokens_count

  index do
    id_column
    column :sentence_number
    column :chapter_id
    column :verses do |sentence|
      sentence.verse_range
    end
    column :tokens_count
    column :words_count
    column :text do |sentence|
      span sentence.text_qpc_hafs, class: 'qpc-hafs quran-text'
    end
  end

  show do
    attributes_table do
      row :sentence_number
      row :chapter_id
      row :first_verse
      row :last_verse
      row :verses_count
      row :tokens_count
      row :words_count
      row :text_uthmani
      row :text_qpc_hafs do |sentence|
        span sentence.text_qpc_hafs, class: 'qpc-hafs quran-text'
      end
    end

    panel 'Tokens' do
      tokens = resource.word_tokens.includes(:head_token)
      table_for tokens do
        column :position_in_sentence
        column :location do |token|
          link_to token.location || token.token_type, [:cms, token]
        end
        column :text do |token|
          span token.text_qpc_hafs, class: 'qpc-hafs quran-text'
        end
        column :token_type
        column :pos do |token|
          token.pos_name
        end
        column :segment_type
        column :relation do |token|
          if token.head_token
            link_to token.rel_label_name, [:cms, token.head_token]
          else
            token.rel_label_name
          end
        end
        column :constituent_label
      end
    end
  end
end
