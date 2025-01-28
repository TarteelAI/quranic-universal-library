# frozen_string_literal: true

ActiveAdmin.register MushafLineAlignment do
  menu parent: 'Quran', priority: 1
  includes :mushaf

  filter :page_number
  filter :line_number
  filter :alignment, as: :select, collection: MushafLineAlignment::LineAlignments
  filter :mushaf,
         as: :searchable_select,
         ajax: { resource: Mushaf }

  index do
    id_column
    column :mushaf
    column :line_number
    column :page_number
    column :alignment
    column :meta_data

    actions
  end

  show do
    attributes_table do
      row :id
      row :mushaf
      row :line_number
      row :page_number
      row :alignment
      row :meta_data do
        if resource.meta_data.present?
          div do
            pre do
              code do
                JSON.pretty_generate(resource.meta_data)
              end
            end
          end
        end
      end
      row :created_at
      row :updated_at
    end
  end

  form do |f|
    f.inputs 'Mushaf line alignment' do
      f.input :mushaf_id,
              as: :searchable_select,
              ajax: { resource: Mushaf }

      f.input :line_number
      f.input :page_number
      f.input :alignment, as: :select, collection: MushafLineAlignment::LineAlignments
     f.input :meta_data, input_html: { data: { controller: 'json-editor', json: resource.meta_data } }
    end

    f.actions
  end

  permit_params do
    [
      :mushaf_id,
      :line_number,
      :page_number,
      :alignment,
      :meta_data
    ]
  end

end
