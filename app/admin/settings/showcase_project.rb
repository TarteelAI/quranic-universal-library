ActiveAdmin.register ShowcaseProject do
  menu parent: 'Settings', priority: 11, label: 'Showcase'
  includes :user

  filter :name
  filter :project_type, as: :select, collection: -> { ShowcaseProject::PROJECT_TYPES.invert }
  filter :owner_name
  filter :published
  filter :created_at

  scope :all, default: true
  scope('Pending review') { |projects| projects.where(published: false) }
  scope('Published') { |projects| projects.where(published: true) }

  index do
    id_column
    column :name
    column(:project_type) { |project| project.project_type_name }
    column(:platforms) { |project| project.platform_names.join(', ') }
    column :owner_name
    column(:submitted_by) { |project| project.user&.email }
    column :published
    column :created_at
    actions
  end

  show do
    attributes_table do
      row :id
      row :name
      row(:project_type) { resource.project_type_name }
      row(:platforms) { resource.platform_names.join(', ') }
      row :description
      row :website_url
      row :app_store_url
      row :play_store_url
      row :repository_url
      row :owner_name
      row :owner_type
      row :qul_resources_used
      row(:submitted_by) { resource.user&.email }
      row :published
      row :logo do
        image_tag(resource.logo, class: 'img-thumbnail', style: 'max-width: 200px') if resource.logo.attached?
      end
      row :created_at
      row :updated_at
    end

    active_admin_comments
  end

  controller do
    include ActiveStorage::SetCurrent
  end

  form do |f|
    f.semantic_errors(*f.object.errors.attribute_names)

    f.inputs 'Project' do
      f.input :name, required: true
      f.input :project_type, as: :select, collection: ShowcaseProject::PROJECT_TYPES.invert, include_blank: false
      f.input :platforms, as: :check_boxes, collection: ShowcaseProject::PLATFORMS.invert
      f.input :description
      f.input :qul_resources_used, label: 'QUL resources used'
      f.input :logo_file, as: :file, label: 'Logo',
              hint: f.object.logo.attached? ? image_tag(f.object.logo, style: 'max-width: 120px') : 'PNG, JPG or WebP, up to 1 MB'
    end

    f.inputs 'Links' do
      f.input :website_url
      f.input :app_store_url
      f.input :play_store_url
      f.input :repository_url
    end

    f.inputs 'Owner' do
      f.input :owner_name
      f.input :owner_type, as: :select, collection: ShowcaseProject::OWNER_TYPES.invert
    end

    f.inputs 'Listing' do
      f.input :published
    end

    f.actions
  end

  permit_params do
    [
      :name,
      :project_type,
      :description,
      :website_url,
      :app_store_url,
      :play_store_url,
      :repository_url,
      :owner_name,
      :owner_type,
      :qul_resources_used,
      :published,
      :logo_file,
      { platforms: [] }
    ]
  end
end
