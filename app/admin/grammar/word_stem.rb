# frozen_string_literal: true

ActiveAdmin.register WordStem do
  menu parent: 'Grammar'
  permit_params :stem_id, :word_id
  includes :word, :stem
  filter :stem,
         as: :searchable_select,
         ajax: { resource: Stem }

  filter :word,
         as: :searchable_select,
         ajax: { resource: Word }

  show do
    attributes_table do
      row :id
      row :word
      row :stem
      row :created_at
      row :updated_at
    end
  end

  form do |f|
    f.inputs 'WordStem Details' do
      f.input :stem_id
      f.input :word_id
    end

    f.actions
  end


  index do
    id_column
    column :word_id do |resource|
      word = resource.word
      link_to(word.text_qpc_hafs, admin_word_path(word), class: 'quran-text qpc-hafs')
    end

    column :stem_id do |resource|
      stem = resource.stem
      link_to(stem.text_clean, admin_stem_path(stem), class: 'quran-text qpc-hafs')
    end

    actions
  end
end
