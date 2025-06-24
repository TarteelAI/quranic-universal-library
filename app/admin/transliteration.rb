# frozen_string_literal: true

ActiveAdmin.register Transliteration do
  menu parent: 'Content'
  actions :all, except: :destroy
  ActiveAdminViewHelpers.versionate(self)

  filter :language,
         as: :searchable_select,
         ajax: { resource: Language }
  filter :resource_type, as: :select, collection: %w[Verse Word]
  filter :resource_id

  show do
    attributes_table do
      row :id
      row :text
      row :language
      row :resource
      row :resource_content
      row :created_at
      row :updated_at
    end

    ActiveAdminViewHelpers.diff_panel(self, resource) if params[:version]
  end

  permit_params do
    %i[language_id resource_type resource_id text language_name resource_content_id]
  end

  index do
    id_column

    column :language do |resource|
      link_to resource.language_name, cms_language_path(resource.language_id)
    end

    column :resource_type

    column :text

    actions
  end

  form do |f|
    f.inputs 'Transliteration Detail' do
      f.input :text
      f.input :language_id,
              required: true,
              as: :searchable_select,
              ajax: { resource: Language }
      f.input :resource_content
      f.input :language_name
      f.input :resource_id
      f.input :resource_type, as: :select, collection: %w[Verse Word]
    end
    f.actions
  end
end
