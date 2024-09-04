# frozen_string_literal: true

ActiveAdmin.register MushafLineAlignment do
  menu parent: 'Quran', priority: 1
  includes :mushaf

  filter :page_number
  filter :line_number
  filter :alignment
  filter :mushaf,
         as: :searchable_select,
         ajax: { resource: Mushaf }

  index do
    id_column
    column :mushaf
    column :line_number
    column :page_number
    column :alignment
    column :properties

    actions
  end

  show do
    attributes_table do
      row :id
      row :mushaf
      row :line_number
      row :page_number
      row :alignment
      row :properties

      row :created_at
      row :updated_at
    end
  end
end
