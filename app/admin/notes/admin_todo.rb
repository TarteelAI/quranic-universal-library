# frozen_string_literal: true

ActiveAdmin.register AdminTodo do
  menu parent: 'Notes'

  filter :resource_content,
         as: :searchable_select,
         ajax: { resource: ResourceContent }
  filter :tags, as: :select, collection: AdminTodo::TAGS
  filter :is_finished
  filter :description

  permit_params do
    %i[is_finished description]
  end

  show do
    attributes_table do
      row :id
      row :description do
        simple_format(resource.description)
      end
      row :is_finished
      row :resource_content
      row :created_at
      row :updated_at
    end
  end
end
