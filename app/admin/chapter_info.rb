# frozen_string_literal: true

ActiveAdmin.register ChapterInfo do
  menu parent: 'Content', priority: 3
  actions :all, except: :destroy
  ActiveAdminViewHelpers.versionate(self)

  filter :chapter,
         as: :searchable_select,
         ajax: { resource: Chapter }

  filter :language,
         as: :searchable_select,
         ajax: { resource: Language }

  filter :text

  permit_params do
    %i[text language_name language_id source short_text resource_content_id chapter_id]
  end

  index do
    id_column

    column :language do |resource|
      link_to resource.language_name, cms_language_path(resource.language_id) if resource.language_id
    end

    column :chapter do |resource|
      link_to resource.chapter_id, cms_chapter_path(resource.chapter_id)
    end

    actions
  end

  show do
    attributes_table do
      row :id
      row :chapter do |object|
        link_to object.chapter_id, cms_chapter_path(object.chapter)
      end
      row :language
      row :resource_content do |object|
        object.get_resource_content&.name
      end

      row :text do |resource|
        div class: resource.language_name do
          safe_html resource.text
        end
      end
      row :short_text
      row :created_at
      row :updated_at
    end

    ActiveAdminViewHelpers.diff_panel(self, resource) if params[:version]
  end

  form do |f|
    f.inputs 'Chapter Info Details' do
      f.input :chapter,
              as: :searchable_select,
              ajax: { resource: Chapter }

      f.input :language_id,
              as: :searchable_select,
              ajax: { resource: Language }

      f.input :resource_content_id,
              as: :searchable_select,
              ajax: { resource: ResourceContent }

      f.input :source
      f.input :short_text

      f.input :text, input_html: {data: {controller: 'tinymce'}}
    end
    f.actions
  end
end
