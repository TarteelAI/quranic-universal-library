ActiveAdmin.register Contributor do
  menu parent: 'Settings', priority: 10

  filter :name
  filter :url
  filter :created_at

  show do
    attributes_table do
      row :id
      row :name
      row :url
      row :published
      row :description do
        resource.description.to_s.html_safe
      end
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

    def attach_logo(resource, logo_params)
      if logo_params.present?
        resource.attach_logo(
          io: logo_params.tempfile,
          filename: logo_params.original_filename
        )
      end
    end

    def create
      resource = build_resource
      attach_logo(resource, params[:contributor][:logo])
      super
    end

    def update
      attach_logo(resource, params[:contributor][:logo])
      super
    end
  end

  form do |f|
    f.inputs do
      f.input :name, required: true
      f.input :url
      f.input :published
      f.input :description, input_html: { data: { controller: 'tinymce' } }
      f.input :logo, as: :file, hint: f.object.logo.attached? ? image_tag(f.object.logo) : content_tag(:span, 'No logo attached')
    end

    f.actions
  end

  permit_params do
    %i[
    name
    url
    description
    published
   ]
  end
end