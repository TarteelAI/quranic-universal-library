# frozen_string_literal: true

ActiveAdmin.register Transliteration do
  menu parent: 'Content'
  actions :all, except: :destroy
  includes :language, :verse

  ActiveAdminViewHelpers.versionate(self)

  filter :language,
         as: :searchable_select,
         ajax: { resource: Language }
  filter :resource_content_id
  filter :verse_key
  filter :chapter_id

  show do
    attributes_table do
      row :id
      row :verse
      row :text do |resource|
        div class: resource.language_name.to_s.downcase do
          safe_html resource.text
        end
      end
      row :language
      row :resource_content
      row :created_at
      row :updated_at
    end

    ActiveAdminViewHelpers.diff_panel(self, resource) if params[:version]
  end

  permit_params do
    %i[language_id verse_id text language_name resource_content_id]
  end

  index do
    id_column

    column :language do |resource|
      link_to resource.language_name, cms_language_path(resource.language_id)
    end

    column :verse_key

    column :text do |resource|
      safe_html resource.text
    end

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
      f.input :verse_id
    end
    f.actions
  end
end
