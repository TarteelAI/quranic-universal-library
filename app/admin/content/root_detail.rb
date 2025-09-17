# frozen_string_literal: true

ActiveAdmin.register RootDetail do
  menu parent: 'Content'
  actions :all, except: :destroy
  ActiveAdminViewHelpers.versionate(self)

  permit_params do
    %i[root_id language_id language_name resource_content_id root_detail meta_data]
  end

  filter :root_id,
         as: :searchable_select,
         ajax: { resource: Root }
  filter :language,
         as: :searchable_select,
         ajax: { resource: Language }
  filter :resource_content,
         as: :searchable_select,
         ajax: { resource: ResourceContent }
  filter :root_detail
  filter :created_at
  filter :updated_at

  index do
    id_column
    column :root_id do |resource|
      link_to resource.root_id, [:cms, resource.root] if resource.root
    end
    column :language_name
    column :resource_content do |resource|
      rc = resource.resource_content
      link_to(rc.name, [:cms, rc]) if rc
    end

    # show a short plain-text preview (sanitized / stripped of tags)
    column :root_detail do |resource|
      text = resource.root_detail.to_s
      # strip HTML tags for safe short preview in table cell, then truncate
      preview = ActionController::Base.helpers.strip_tags(text).squish.truncate(140)
      span preview
    end

    column :created_at
    column :updated_at
    actions
  end

  show do
    attributes_table do
      row :id
      row :root_id do
        link_to resource.root_id, [:cms, resource.root] if resource.root
      end
      row :language_id
      row :language_name
      row :resource_content do
        r = resource.resource_content
        link_to r.name, [:cms, r] if r
      end

      # Render safe HTML similar to Translation.show (uses safe_html helper present in app)
      row :root_detail do
        div class: resource.language_name.to_s.downcase do
          # safe_html is used across app (as in Translation). It sanitizes and marks HTML safe.
          safe_html resource.root_detail
        end
      end

      row :meta_data do
        pre JSON.pretty_generate(resource.meta_data || {})
      end

      row :created_at
      row :updated_at
    end

    ActiveAdminViewHelpers.diff_panel(self, resource) if params[:version]
    ActiveAdminViewHelpers.compare_panel(self, resource) if params[:compare]
    active_admin_comments
  end

  form do |f|
    f.inputs 'Root Detail' do
      f.input :root_id
      # Admins can paste HTML or plain text — consider a WYSIWYG editor if desired
      f.input :root_detail, as: :text

      f.input :resource_content,
              as: :searchable_select,
              ajax: { resource: ResourceContent }

      f.input :language,
              as: :searchable_select,
              ajax: { resource: Language }

      f.input :language_name
    end

    f.actions
  end
end
