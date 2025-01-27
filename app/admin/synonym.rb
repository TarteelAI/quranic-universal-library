# frozen_string_literal: true

ActiveAdmin.register Synonym do
  menu parent: 'Settings'

  permit_params :text, :synonyms

  filter :text
  filter :text_simple
  filter :text_uthmani
  filter :words_count
  filter :approved
  filter :where_synonyms_cont, label: :synonyms, as: :string
  filter :en_transliterations_cont, label: :en_transliterations, as: :string

  index do
    id_column
    column :text, class: 'quran-text qpc-hafs'
    column :text_simple, class: 'quran-text qpc-hafs'
    column :text_uthmani, class: 'quran-text qpc-hafs'
    column :words_count
    column :approved

    column :created_at
    actions
  end

  show do
    attributes_table do
      row :id
      row :approved
      row :text
      row :text_simple
      row :text_uthmani
      row :words_count
      row :synonyms do |resource|
        div resource.synonyms.join(', '), class: 'quran-text qpc-hafs'
      end
      row :en_transliterations

      row :created_at
      row :updated_at

      row :words do |resource|
        table do
          thead do
            td :word_id
            td :location
            td :text
          end

          tbody do
            resource.words.each do |word|
              tr do
                td word.id
                td word.location
                td link_to(word.text_uthmani_simple,
                           "/admin/words?utf8=%E2%9C%93&q%5Btext_uthmani_simple_eq%5D=#{word.text_uthmani_simple}")
              end
            end
          end
        end

        nil
      end
    end
  end
end
