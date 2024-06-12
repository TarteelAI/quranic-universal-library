# frozen_string_literal: true

# == Schema Information
#
# Table name: transliterations
#
#  id                  :integer          not null, primary key
#  language_name       :string
#  resource_type       :string
#  text                :text
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  language_id         :integer
#  resource_content_id :integer
#  resource_id         :integer
#
# Indexes
#
#  index_transliterations_on_language_id                    (language_id)
#  index_transliterations_on_resource_content_id            (resource_content_id)
#  index_transliterations_on_resource_type_and_resource_id  (resource_type,resource_id)
#
ActiveAdmin.register Transliteration do
  menu parent: 'Content'
  actions :all, except: :destroy
  ActiveAdminViewHelpers.versionate(self)

  filter :language
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
      link_to resource.language_name, admin_language_path(resource.language_id)
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
