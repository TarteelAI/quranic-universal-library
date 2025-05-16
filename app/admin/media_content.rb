# frozen_string_literal: true

ActiveAdmin.register MediaContent do
  menu parent: 'Media', priority: 2
  actions :all, except: :destroy
  filter :language,
         as: :searchable_select,
         ajax: { resource: Language }

  show do
    attributes_table do
      row :id
      row :resource
      row :language
      row :url
      row :created_at
      row :updated_at
      row :embed_text do |resource|
        div safe_html(resource.embed_text)
      end
    end
  end

  index do
    id_column
    column :author_name
    column :resource_content
    column :language
    actions
  end

  def scoped_collection
    super.includes :language, :resource_content
  end
end
