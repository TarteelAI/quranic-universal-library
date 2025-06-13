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
  filter :cardinality_type, as: :select, collection: ResourceContent.collection_for_cardinality_type
  filter :resource_type, as: :select, collection: DownloadableResource::RESOURCE_TYPES

  searchable_select_options(
    scope: DownloadableResource,
    text_attribute: :humanize,
    filter: lambda do |term, scope|
      scope.ransack(
        name_cont: term,
        m: 'or'
      ).result
    end
  )

  action_item :refresh_downloads, only: :show, if: -> { can? :refresh_downloads, resource } do
    link_to 'Refresh downloads', '#_',
            data: { controller: 'ajax-modal', url: refresh_downloads_cms_downloadable_resource_path(resource) }
  end

  action_item :notify_users, only: :show, if: -> { can? :notify_users, resource } do
    link_to notify_users_cms_downloadable_resource_path(resource), method: :put, data: { confirm: 'Are you sure? This action will send an email to all users who has downloaded this resource.' } do
      'Notify users'
    end
  end

  member_action :refresh_downloads, method: ['get', 'put'], if: -> { can? :refresh_downloads, resource } do
    authorize! :refresh_downloads, resource

    if request.get?
      render partial: 'admin/confirm_refresh_downloadable_resource'
    else
      # Restart sidekiq if it's not running
      Utils::System.start_sidekiq
      notify = params[:notify_users] == '1'
      AsyncResourceActionJob.perform_later(resource, :refresh_export!, send_update_email: notify)

      redirect_to [:cms, resource], notice: "Data will be exported in the background. Please check back later."
    end
  end

  member_action :notify_users, method: 'put', if: -> { can? :notify_users, resource } do
    authorize! :notify_users, resource
    # Restart sidekiq if it's not running
    Utils::System.start_sidekiq

    resource.notify_users
    redirect_to [:cms, resource], notice: "System will send email to all users who has downloaded this resource."
  end

  controller do
    include ActiveStorage::SetCurrent
  end

  show do
    attributes_table do
      row :id
      row :name
      row :resource_content
      row :resource_type
      row :language
      row :download_count
      row :published
      row :position
      row :info
      row :meta_data do
        if resource.meta_data.present?
          div do
            pre do
              code do
                JSON.pretty_generate(resource.meta_data)
              end
            end
          end
        end
      end
      row :tags do
        resource.downloadable_resource_tags.each do |t|
          link_to t.name, [:cms, t]
        end
      end

      row :created_at
      row :updated_at
    end

    panel 'Downloadable files' do
      table do
        thead do
          th 'Id'
          th 'Name'
          th 'Type'
          th 'Download count'
          th 'Actions'
        end

        tbody do
          resource.downloadable_files.with_attached_file.each do |file|
            tr do
              td link_to(file.id, [:cms, file])
              td file.name
              td file.file_type
              td file.download_count
              td link_to 'View', file.file.url, target: '_blank'
            end
          end
        end
      end
    end

    panel 'Related resources' do
      table do
        thead do
          th 'Id'
          th 'Name'
          th 'Type'
          th 'Actions'
        end

        tbody do
          resource.related_resources.each do |r|
            tr do
              td link_to(r.id, [:cms, r])
              td r.name
              td r.resource_type
              td link_to 'View', [:cms, r], target: '_blank'
            end
          end
        end
      end
    end

    active_admin_comments
  end

  form data: { turbo: false } do |f|
    f.inputs 'Downloadable resource detail' do
      if f.object.errors.any?
        div class: 'alert alert-danger' do
          ul do
            f.object.errors.full_messages.each do |e|
              li e
            end
          end
        end
      end

      f.input :name
      f.input :published

      f.input :position

      f.input :cardinality_type, as: :searchable_select, collection: ResourceContent.collection_for_cardinality_type
      f.input :resource_type, as: :searchable_select, collection: DownloadableResource::RESOURCE_TYPES
      f.input :resource_content_id,
              as: :searchable_select,
              ajax: { resource: ResourceContent }

      f.input :info, input_html: { data: { controller: 'tinymce' } }
      f.input :meta_data, input_html: { data: { controller: 'json-editor', json: resource.meta_data } }
      f.inputs "Select Tags" do
        f.has_many :downloadable_resource_taggings, allow_destroy: true do |tag_form|
          tag_form.input :id, as: :hidden
          tag_form.input :downloadable_resource_tag_id,
                  as: :select,
                  collection: DownloadableResourceTag.pluck(:name, :id),
                  input_html: { data: { controller: 'select2' } }

        end
      end
    end

    f.actions
  end

  permit_params do
    [
      :name,
      :info,
      :position,
      :published,
      :resource_type,
      :resource_content_id,
      :cardinality_type,
      :meta_data,
      downloadable_resource_taggings_attributes: [:id, :downloadable_resource_tag_id, :_destroy]
    ]
  end
end
