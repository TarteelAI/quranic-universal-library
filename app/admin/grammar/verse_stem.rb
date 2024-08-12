# frozen_string_literal: true

ActiveAdmin.register VerseStem do
  menu parent: 'Grammar'
  actions :all, except: :destroy

  filter :text_clean
  filter :text_madani

  permit_params :text_madani, :text_clean

  index do
    id_column
    column :verse
    column :text_madani
    column :text_clean

    actions
  end

  show do
    attributes_table do
      row :id
      row :verse
      row :text_clean
      row :text_madani
      row :created_at
      row :updated_at
    end
  end
end
