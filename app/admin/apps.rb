# frozen_string_literal: true

# The apps directory (/apps and the home page's apps band): editors publish, edit, feature and
# remove apps here. Submissions from the form on /apps arrive unpublished. Admins only (Ability),
# because a submission holds the submitter's contact address.
ActiveAdmin.register App do
  menu parent: 'Settings', label: 'Apps directory'

  scope :all, default: true
  scope('Submitted') { |apps| apps.where(published: false) }
  scope('Published') { |apps| apps.where(published: true) }

  filter :name
  filter :url
  filter :published
  filter :featured
  filter :created_at

  includes :user, icon_attachment: :blob

  index do
    id_column
    column(:icon) { |app| image_tag(app.icon, size: 32, alt: '') if app.icon.attached? }
    column :name
    column :url
    column :published
    column :featured
    column :user
    column :created_at
    actions
  end

  show do
    attributes_table do
      row :id
      row(:icon) { |app| image_tag(app.icon, size: 96, alt: '') if app.icon.attached? }
      row :name
      row(:project_type) { |app| AppDirectory::PROJECT_TYPES.fetch(app.project_type).label }
      row :url
      row :app_store_url
      row :play_store_url
      row :source_url
      row :kind
      row :description
      row(:platforms) { |app| app.platforms.map { |key| AppDirectory::PLATFORMS.fetch(key).label }.join(', ') }
      row(:uses) { |app| app.uses.map { |key| Catalog::Taxonomy.type(key).label }.join(', ') }
      row :evidence
      row :published
      row :featured
      row :contact
      row :consent
      row :user
      row :import_key
      row :created_at
      row :updated_at
    end
    active_admin_comments
  end

  form do |f|
    f.semantic_errors(*f.object.errors.attribute_names)
    f.inputs do
      f.input :published, hint: 'Shown on /apps. Needs a kind and a description.'
      f.input :featured, hint: 'Listed first. The home page shows the first eight apps.'
      f.input :name
      f.input :project_type, as: :select, include_blank: false,
                             collection: AppDirectory::PROJECT_TYPES.values.map { |type| [type.label, type.key] }
      f.input :url, label: 'Link', hint: 'The main link: the site, else a store page or the repo.'
      f.input :app_store_url, label: 'App Store link'
      f.input :play_store_url, label: 'Google Play link'
      f.input :source_url, label: 'Source code link'
      f.input :kind, hint: 'A short noun for the home page, such as "Hifz app".'
      f.input :description, as: :text, input_html: { rows: 3 }
      f.input :platforms, as: :check_boxes, hint: 'Apps only.',
                          collection: AppDirectory::PLATFORMS.values.map { |platform| [platform.label, platform.key] }
      f.input :uses, as: :check_boxes, label: 'Resources used',
                     collection: Catalog::Taxonomy.types.map { |type| [type.label, type.key] }
      f.input :icon_upload, as: :file, label: 'Icon', hint: 'PNG, JPEG or WebP, up to 1 MB. Replaces the icon.'
      f.input :evidence, hint: 'A public page where the app credits QUL.'
      f.input :contact, hint: 'The submitter. Never shown on the site.'
    end
    f.actions
  end

  permit_params :published, :featured, :name, :project_type, :url, :app_store_url, :play_store_url, :source_url,
                :kind, :description, :icon_upload, :evidence, :contact, platforms: [], uses: []
end
