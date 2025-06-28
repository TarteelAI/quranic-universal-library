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
  filter :footnotes_count
  filter :language,
         as: :searchable_select,
         ajax: { resource: Language }
  filter :resource_content,
         as: :searchable_select,
         ajax: { resource: ResourceContent }
  filter :verse,
         as: :searchable_select,
         ajax: { resource: Verse }
  filter :created_at
  filter :updated_at

  action_item :view_export_data, only: :show, if: -> { can? :manage, resource } do
    link_to 'View export data', '#_',
            data: { controller: 'ajax-modal', url: view_export_data_cms_translation_path(resource) }
  end

  index do
    id_column

    column :language, &:language_name
    column :verse_id do |resource|
      link_to resource.verse_key, cms_verse_path(resource.verse_id)
    end
    column :text, sortable: :text do |resource|
      resource.text.first(100)
    end

    column :updated_at

    actions
  end

  show do
    attributes_table do
      row :id

      row :resource_content do
        r = resource.get_resource_content
        link_to(r.name, [:cms, r])
      end
      row :language
      row :priority
      row :resource_name
      row :page_number
      row :rub_el_hizb
      row :verse do |resource|
        div do
          link_to resource.verse.verse_key, cms_verse_path(resource.verse)
        end
        div class: 'qpc-hafs' do
          resource.verse.text_qpc_hafs
        end
      end
      row :text do |resource|
        div class: resource.language_name.to_s.downcase, 'data-controller': 'translation' do
          safe_html resource.text
        end
      end

      row :created_at
      row :updated_at
    end

    panel 'Footnotes' do
      table do
        thead do
          td :id
          td :text
          td :created_at
          td :updated_at
        end

        tbody do
          resource.foot_notes.each do |foot_note|
            tr do
              td link_to foot_note.id, cms_foot_note_path(foot_note)
              td safe_html(foot_note.text)
              td foot_note.created_at
              td foot_note.updated_at
            end
          end
        end
      end
    end

    ActiveAdminViewHelpers.diff_panel(self, resource) if params[:version]
    ActiveAdminViewHelpers.compare_panel(self, resource) if params[:compare]

    active_admin_comments
  end

  member_action :view_export_data, method: :get do
    render partial: 'admin/translation/export_data'
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
