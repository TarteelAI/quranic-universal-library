# frozen_string_literal: true

ActiveAdmin.register Tafsir do
  menu parent: 'Content'
  actions :all, except: :destroy
  ActiveAdminViewHelpers.versionate(self)

  permit_params do
    %i[text archived verse_id language_name language_id resource_content_id resource_name start_verse_id end_verse_id group_tafsir_id]
  end

  filter :language,
         as: :searchable_select,
         ajax: { resource: Language }

  filter :resource_content,
         as: :searchable_select,
         ajax: { resource: ResourceContent }

  filter :verse_key
  filter :group_verse_key_from
  filter :group_verse_key_to
  filter :text
  filter :archived
  filter :verse,
         as: :searchable_select,
         ajax: { resource: Verse }
  filter :chapter,
         as: :searchable_select,
         ajax: { resource: Chapter }

  index do
    id_column
    column :language
    column :archived, sortable: :archived
    column :verse_id do |resource|
      link_to resource.verse_id, cms_verse_path(resource.verse_id)
    end
    column :verse_key
    column :group do |resource|
      "#{resource.group_verse_key_from} - #{resource.group_verse_key_to}"
    end
    column :group_size, sortable: :group_verses_count do |resource|
      resource.group_verses_count
    end
    column :name do |resource|
      resource_content = resource.get_resource_content
      link_to resource_content.name, [:cms, resource_content]
    end
  end

  show do
    attributes_table do
      row :id
      row :verse
      row :archived
      row :language
      row :language_name
      row :verse_key
      row :resource_content do
        r = resource.get_resource_content
        link_to r.name, [:cms, r]
      end
      row :resource_name
      row :group_verse_key_from
      row :group_verse_key_to
      row :group_tafsir_id do
        link_to "#{resource.group_verse_key_from}-#{resource.group_verse_key_to}",
                "/cms/tafsirs/#{resource.group_tafsir_id}"
      end
      row :group_verses_count

      row :text do
        resource.text.to_s.html_safe
      end
      row :created_at
      row :updated_at
    end

    ActiveAdminViewHelpers.diff_panel(self, resource) if params[:version]
    ActiveAdminViewHelpers.compare_panel(self, resource) if params[:compare]
  end

  form do |f|
    f.inputs 'Tafisr Detail' do
      f.input :text, input_html: { data: { controller: 'tinymce' } }
      f.input :archived
      f.input :verse_id,
              as: :searchable_select,
              ajax: { resource: Verse }

      f.input :start_verse_id,
              as: :searchable_select,
              ajax: { resource: Verse }

      f.input :end_verse_id,
              as: :searchable_select,
              ajax: { resource: Verse }

      f.input :group_tafsir_id,
              as: :searchable_select,
              ajax: { resource: Verse }

      f.input :resource_content,
              as: :searchable_select,
              ajax: { resource: ResourceContent }

      f.input :resource_name

      f.input :language,
              as: :searchable_select,
              ajax: { resource: Language }

      f.input :language_name
    end

    f.actions
  end
end
