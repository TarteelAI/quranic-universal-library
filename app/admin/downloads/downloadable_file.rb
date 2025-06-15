# frozen_string_literal: true

ActiveAdmin.register DownloadableFile do
  menu parent: 'Downloads', priority: 1
  includes :downloadable_resource

  filter :name
  filter :downloadable_resource,
         as: :searchable_select,
         ajax: { resource: DownloadableResource }
  filter :published
  filter :file_type
  filter :download_count
  filter :created_at
  filter :updated_at

  controller do
    include ActiveStorage::SetCurrent
  end

  index do
    id_column
    column :name
    column :downloadable_resource
    column :download_count
    column :created_at
    column :updated_at

    actions
  end

  show do
    attributes_table do
      row :id
      row :name
      row :downloadable_resource
      row :file_type
      row :token
      row :download_count
      row :published
      row :position
      row :info
      row :file do |file|
        if file.file.attached?
          link_to 'Download', rails_blob_path(file.file, disposition: 'attachment')
        else
          'No file attached'
        end
      end

      row :created_at
      row :updated_at
    end

    panel "Downloaded by", id: 'verse-words' do
      table border: 1 do
        thead do
          td '#'
          td 'User'
          td 'Last download at'
          td 'Download cunt'
        end

        tbody  do
          resource.user_downloads.includes(:user).each_with_index do |download, i|
            tr do
              td i + 1
              td link_to(download.user.name, [:cms, download.user])
              td download.last_download_at
              td download.download_count
            end
          end
        end
      end
    end

    active_admin_comments
  end

  form do |f|
    f.inputs 'Downloadable resource detail' do
      f.input :name
      f.input :published
      f.input :position

      f.input :downloadable_resource_id,
              as: :searchable_select,
              ajax: { resource: DownloadableResource }

      f.input :file_type

      f.input :file, as: :file
      f.input :info, input_html: { data: { controller: 'tinymce' } }
    end

    f.actions
  end

  permit_params do
    %i[name published position downloadable_resource_id file file_type info]
  end

  member_action :upload_file, method: 'post' do
    permitted = params.require(:downloadable_resource).permit files: []

    permitted['files'].each do |attachment|
      resource.files.attach(attachment)
    end

    redirect_to [:cms, resource], notice: 'File saved successfully'
  end
end
