# frozen_string_literal: true

ActiveAdmin.register WordRoot do
  menu parent: 'Grammar'
  permit_params :word_id, :root_id

  filter :root_id, as: :searchable_select,
                   ajax: { resource: Root }

  filter :word_id, as: :searchable_select,
                   ajax: { resource: Word }

  show do
    attributes_table do
      row :id
      row :word
      row :root do
        link_to resource.root.text_clean, "/admin/roots/#{resource.root_id}"
      end
      row :created_at
      row :updated_at
    end
  end

  form do |f|
    f.inputs 'WordRoot Details' do
      f.input :root_id
      f.input :word_id
    end

    f.actions
  end

  permit_params do
    %i[word_id root_id]
  end

  def scoped_collection
    super.includes :word, :root
  end

  index do
    id_column
    column :word_id do |resource|
      word = resource.word
      link_to(word.text_qpc_hafs, admin_word_path(word), class: 'quran-text qpc-hafs')
    end

    column :root_id do |resource|
      root = resource.root
      link_to(root.text_clean, "/admin/roots/#{root.id}", class: 'quran-text qpc-hafs')
    end

    actions
  end
end
