# frozen_string_literal: true

ActiveAdmin.register Translation do
  menu parent: 'Content'
  actions :all, except: [:destroy, :new, :create]
  includes :language

  searchable_select_options(
    scope: Translation,
    text_attribute: :text
  )

  ActiveAdminViewHelpers.versionate(self)

  filter :text
  filter :language,
         as: :searchable_select,
         ajax: { resource: Language }
  filter :resource_content,
         as: :searchable_select,
         ajax: { resource: ResourceContent }
  filter :verse,
         as: :searchable_select,
         ajax: { resource: Verse }

  index do
    id_column

    column :language, &:language_name
    column :verse_id do |resource|
      link_to resource.verse_key, admin_verse_path(resource.verse_id)
    end
    column :text, sortable: :text do |resource|
      resource.text.first(100)
    end

    actions
  end

  show do
    attributes_table do
      row :id
      row :verse do |resource|
        link_to resource.verse.verse_key, admin_verse_path(resource.verse)
      end
      row :resource_content do
        r = resource.get_resource_content
        link_to(r.name, [:admin, r])
      end
      row :language
      row :priority
      row :resource_name
      row :page_number
      row :rub_el_hizb

      row :text do |resource|
        div class: resource.language_name.to_s.downcase, 'data-controller': 'translation' do
          resource.text.html_safe
        end
      end

      row :created_at
      row :updated_at
    end

    ActiveAdminViewHelpers.diff_panel(self, resource) if params[:version]
    ActiveAdminViewHelpers.compare_panel(self, resource) if params[:compare]

    active_admin_comments
  end

  permit_params do
    %i[language_id verse_id text language_name resource_content_id]
  end

  form do |f|
    f.inputs 'Translation Detail' do
      f.input :text, as: :text

      f.input :resource_content,
              as: :searchable_select,
              ajax: { resource: ResourceContent }

      f.input :resource_name

      f.input :language,
              as: :searchable_select,
              ajax: { resource: Language }

      f.input :language_name
      f.input :verse_id
    end

    f.actions
  end
end
