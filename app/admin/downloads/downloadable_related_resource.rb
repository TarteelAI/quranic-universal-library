# frozen_string_literal: true

ActiveAdmin.register DownloadableRelatedResource do
  menu parent: 'Downloads', priority: 1
  includes :downloadable_resource, :related_resource

  filter :downloadable_resource,
         as: :searchable_select,
         ajax: { resource: DownloadableResource }

  filter :created_at
  filter :updated_at

  index do
    id_column
    column :downloadable_resource
    column :related_resource
    column :created_at
    column :updated_at

    actions
  end

  show do
    attributes_table do
      row :id
      row :downloadable_resource do
        link_to(
          resource.downloadable_resource.humanize,
          [:cms, resource.downloadable_resource]
        ) if resource.downloadable_resource
      end
      row :related_resource do
        link_to(
          resource.related_resource.humanize,
          [:cms, resource.related_resource]
        ) if resource.related_resource
      end

      row :created_at
      row :updated_at
    end

    active_admin_comments
  end

  form do |f|
    f.inputs 'Downloadable related resource detail' do
      f.input :downloadable_resource_id,
              as: :searchable_select,
              ajax: { resource: DownloadableResource }

      f.input :related_resource_id,
              as: :searchable_select,
              ajax: { resource: DownloadableResource }
    end

    f.actions
  end

  permit_params do
    %i[downloadable_resource_id related_resource_id]
  end
end
