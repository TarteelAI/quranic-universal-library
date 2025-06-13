# frozen_string_literal: true

ActiveAdmin.register FootNote do
  menu parent: 'Content'
  actions :all, except: :destroy
  includes :translation, :language
  ActiveAdminViewHelpers.versionate(self)

  filter :translation_id
  filter :text
  filter :language,
         as: :searchable_select,
         ajax: { resource: Language }
  filter :resource_content,
         as: :searchable_select,
         ajax: { resource: ResourceContent }

  show do
    attributes_table do
      row :id
      row :translation
      row :language
      row :resource_content do |foot_note|
        resource_content = foot_note.get_resource_content
        link_to(resource_content.name, [:cms, resource_content]) if resource_content
      end
      row :text do
        div class: resource.language_name do
          safe_html resource.text
        end
      end
      row :created_at
      row :updated_at
    end

    ActiveAdminViewHelpers.diff_panel(self, resource) if params[:version]
  end

  form do |f|
    f.inputs 'Footnote Details' do
      f.input :text
      f.input :language_id,
              required: true,
              as: :searchable_select,
              ajax: { resource: Language }
      f.input :language_name

      f.input :translation_id,
              as: :searchable_select,
              ajax: { resource: Translation }

      f.input :resource_content,
              as: :searchable_select,
              ajax: { resource: ResourceContent }
    end
    f.actions
  end

  index do
    id_column
    column :translation
    column :language
    column :text do |r|
      truncate r.text, length: 100
    end
    actions
  end

  permit_params do
    %i[language_id resource_content_id text translation_id language_name]
  end
end
