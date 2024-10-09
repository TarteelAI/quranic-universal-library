# frozen_string_literal: true

ActiveAdmin.register DownloadableResource do
  menu parent: 'Downloads', priority: 1

  filter :name
  filter :language, as: :searchable_select,
         ajax: { resource: Language }
  filter :resource_content, as: :searchable_select,
         ajax: { resource: ResourceContent }

  filter :files_count
  filter :published
  filter :updated_at
  filter :resource_type, as: :select, collection: DownloadableResource::RESOURCE_TYPES

  searchable_select_options(
    scope: DownloadableResource,
    text_attribute: :name
  )

  action_item :approve, only: :show, if: -> { can? :refresh_downloads, resource } do
    link_to refresh_downloads_admin_downloadable_resource_path(resource), method: :put, data: { confirm: 'Are you sure? this action will export files for this resource again.' } do
      'Refresh downloads'
    end
  end

  member_action :refresh_downloads, method: 'put', if: -> {can? :refresh_downloads, resource} do
    authorize! :refresh_downloads, resource
    # Restart sidekiq if it's not running
    Utils::System.start_sidekiq

    AsyncResourceActionJob.perform_later(resource, :refresh_export!)
    redirect_to [:admin, resource], notice: "Data will be exported in the background. Please check back later."
  end

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

  sidebar 'Downloadable files', only: :show do
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
            td link_to(file.id, [:admin, file])
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
