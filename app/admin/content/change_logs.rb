ActiveAdmin.register ChangeLog do
  menu parent: 'Content'
  config.sort_order = 'created_at_desc'

  includes :resource_content, :user

  filter :resource_content, as: :searchable_select,
         ajax: { resource: ResourceContent }
  filter :user, as: :searchable_select,
         ajax: { resource: User }
  filter :created_at
  filter :published

  controller do
    def create
      build_resource
      resource.user = current_user
      create!
    end
  end

  index do
    id_column
    column :title
    column :resource_content
    column('Created by', &:user)
    column :excerpt
    column :published
    column :created_at
    actions
  end

  show do
    attributes_table do
      row :id
      row :title
      row :resource_content
      row :user
      row :published
      row :created_at
      row :updated_at
      row :excerpt
      row :content do |change_log|
        safe_html change_log.text.to_s
      end
    end

    active_admin_comments
  end

  form do |f|
    f.inputs 'Change log details' do
      f.input :resource_content_id,
              as: :searchable_select,
              ajax: { resource: ResourceContent },
              hint: 'This changelog is attached to a ResourceContent entry.'
      f.input :title
      f.input :published
      f.input :excerpt
    end

    f.inputs 'Content' do
      li class: 'text input optional' do
        f.input :text, input_html: { data: { controller: 'tinymce' } }
      end
    end

    f.actions
  end

  permit_params do
    [
      :resource_content_id,
      :title,
      :published,
      :text,
      :excerpt
    ]
  end
end
