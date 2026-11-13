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
      row :url
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
      f.input :url, label: 'Link'
      f.input :kind, hint: 'A short noun for the home page, such as "Hifz app".'
      f.input :description, as: :text, input_html: { rows: 3 }
      f.input :platforms, as: :check_boxes,
                          collection: AppDirectory::PLATFORMS.values.map { |platform| [platform.label, platform.key] }
      f.input :uses, as: :check_boxes, label: 'Resources used',
                     collection: Catalog::Taxonomy.types.map { |type| [type.label, type.key] }
      f.input :icon_upload, as: :file, label: 'Icon', hint: 'PNG, JPEG or WebP, up to 1 MB. Replaces the icon.'
      f.input :evidence, hint: 'A public page where the app credits QUL.'
      f.input :contact, hint: 'The submitter. Never shown on the site.'
    end
    f.actions
  end

  permit_params :published, :featured, :name, :url, :kind, :description, :icon_upload, :evidence, :contact,
                platforms: [], uses: []
end
