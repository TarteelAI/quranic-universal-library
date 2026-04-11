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
  filter :delivered

  action_item :deliver, only: :show, if: -> { can?(:deliver, resource) && resource.deliverable? } do
    link_to deliver_cms_change_log_path(resource), method: :put, data: { confirm: 'Are you sure? This action will send this changelog email to all users and cannot be repeated.' } do
      'Send changelog email'
    end
  end

  member_action :deliver, method: :put do
    authorize! :deliver, resource
    unless resource.deliverable?
      return redirect_to [:cms, resource], alert: 'Only published changelogs that have not been delivered can be sent.'
    end

    Utils::System.start_sidekiq
    ChangeLogDeliveryJob.perform_later(resource.id)

    redirect_to [:cms, resource], notice: 'Changelog email has been queued for delivery.'
  end

  controller do
    def scoped_collection
      super.includes(:resource_content, :user)
    end

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
    column :delivered
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
      row :delivered
      row :delivered_at
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
