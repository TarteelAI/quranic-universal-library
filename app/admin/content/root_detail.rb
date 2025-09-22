# frozen_string_literal: true

ActiveAdmin.register RootDetail do
  menu parent: 'Content'
  actions :all, except: :destroy
  ActiveAdminViewHelpers.versionate(self)

  permit_params :token_id,
                :root_id,
                :language_id,
                :resource_content_id,
                :text,
                :meta_data

  filter :token_id
  filter :root_id
  filter :language,
         as: :searchable_select,
         ajax: { resource: Language }
  filter :resource_content,
         as: :searchable_select,
         ajax: { resource: ResourceContent }
  filter :text
  filter :created_at
  filter :updated_at

  index do
    id_column

    column :token_id do |resource|
      if resource.respond_to?(:token) && resource.token
        link_to resource.token_id, [:cms, resource.token]
      else
        resource.token_id
      end
    end

    column :root_id do |resource|
      link_to resource.root_id, [:cms, resource.root] if resource.root
    end

    column :language do |resource|
      resource.language&.name
    end

    column :resource_content do |resource|
      rc = resource.resource_content
      link_to rc.name, [:cms, rc] if rc
    end

    column :text do |resource|
      text = resource.text.to_s
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

      row :token_id do
        if resource.respond_to?(:token) && resource.token
          link_to resource.token_id, [:cms, resource.token]
        else
          resource.token_id
        end
      end

      row :root_id do
        link_to resource.root_id, [:cms, resource.root] if resource.root
      end

      row :language do
        resource.language&.name
      end

      row :resource_content do
        r = resource.resource_content
        link_to r.name, [:cms, r] if r
      end

      row :text do
        css_class = resource.language&.name.to_s.downcase
        div class: css_class do
          safe_html resource.text
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
      f.input :token_id
      f.input :root_id
      f.input :text, as: :text
      f.input :resource_content,
              as: :searchable_select,
              ajax: { resource: ResourceContent }
      f.input :language,
              as: :searchable_select,
              ajax: { resource: Language }
    end

    f.actions
  end
end
