# frozen_string_literal: true

ActiveAdmin.register Synonym do
  menu parent: 'Settings'

  permit_params :text, :synonyms

  filter :text
  filter :where_synonyms_cont, label: :synonyms, as: :string

  index do
    id_column
    column :text, class: 'quran-text qpc-hafs'
    column :approved_synonyms do |resource|
      div resource.approved_synonyms.join(', '), class: 'quran-text fs-lg'
    end
    column :created_at
    actions
  end

  show do
    attributes_table do
      row :id
      row :text
      row :approved_synonyms do |resource|
        div resource.approved_synonyms.join(', '), class: 'quran-text qpc-hafs'
      end

      row :synonyms do |resource|
        div resource.synonyms.join(', '), class: 'quran-text qpc-hafs'
      end

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
                           "/cms/words?utf8=%E2%9C%93&q%5Btext_uthmani_simple_eq%5D=#{word.text_uthmani_simple}")
              end
            end
          end
        end

        nil
      end
    end
  end
end
