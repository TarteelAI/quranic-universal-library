# frozen_string_literal: true

ActiveAdmin.register DownloadableResource do
  menu parent: 'Settings', priority: 1
  filter :name

  filter :language, as: :searchable_select,
         ajax: { resource: Language }

  filter :resource_content, as: :searchable_select,
         ajax: { resource: ResourceContent }
  filter :published
  filter :updated_at


  filter :resource_type, as: :select, collection: DownloadableResource::RESOURCE_TYPES

  controller do
    include ActiveStorage::SetCurrent
  end

  form do |f|
    f.inputs 'Downloadable resource detail' do
      f.input :name
      f.input :published

      f.input :position
      f.input :tags, hint: 'Comma separated tags'
      f.input :cardinality_type, as: :searchable_select, collection: ResourceContent.collection_for_cardinality_type
      f.input :resource_type, as: :searchable_select, collection: DownloadableResource::RESOURCE_TYPES
      f.input :resource_content_id,
              as: :searchable_select,
              ajax: { resource: ResourceContent }

      f.input :info, input_html: { data: { controller: 'tinymce' } }
    end

    f.actions
  end

  permit_params do
    %i[name info position published resource_type tags files resource_content_id cardinality_type]
  end

  member_action :upload_file, method: 'post' do
    permitted = params.require(:downloadable_resource).permit files: []

    permitted['files'].each do |attachment|
      resource.files.attach(attachment)
    end

    redirect_to [:admin, resource], notice: 'File saved successfully'
  end


  sidebar 'Downloadable files', only: :show do
    div do
      render 'admin/downloadable_resource_file_form'
    end

    table do
      thead do
        th 'Id'
        th 'Name'
        th 'Type'
        th 'Download count'
        th 'Preview'
      end

      tbody do
        resource.downloadable_files.with_attached_file.each do |file|
          tr do
            td file.id
            td file.name
            td file.file_type
            td file.download_count
            td link_to 'View', file.file.url, target: '_blank'
          end
        end
      end
    end
  end
end
