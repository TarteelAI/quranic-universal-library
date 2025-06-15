# frozen_string_literal: true

ActiveAdmin.register Radio::Station do
  ActiveAdminViewHelpers.render_translated_name_sidebar(self)

  menu parent: 'Audio'
  filter :name
  filter :parent, as: :searchable_select,
         ajax: {
           resource: Radio::Station
         }

  actions :all, except: :destroy
  searchable_select_options(
    scope: Radio::Station,
    text_attribute: :name
  )

  permit_params do
    %i[name description cover_image profile_picture parent_id]
  end

  index do
    id_column
    column :name
    column :cover_image
    column :parent_id
    column :profile_picture
    actions
  end

  show do
    attributes_table do
      row :id
      row :name
      row :parent

      row :description do |resource|
        div do
          safe_html resource.description
        end
      end

      row :profile_picture do |resource|
        url = resource.profile_picture_url
        if url
          image_tag url
        end
      end

      row :cover_image do |resource|
        url = resource.cover_url
        if url
          image_tag url
        end
      end
      row :created_at
      row :updated_at
    end

    panel 'Sub stations' do
      table do
        thead do
          td 'Id'
          td 'Name'
        end

        tbody do
          resource.sub_stations.each do |s|
            tr do
              td link_to(s.id, [:cms, s])
              td s.name
            end
          end
        end
      end
    end

    active_admin_comments
  end

  form do |f|
    f.inputs 'Reciter Detail' do
      f.input :name
      f.input :cover_image
      f.input :profile_picture
      f.input :parent_id,
              as: :searchable_select,
              ajax: { resource: Radio::Station }

      f.input :description, input_html: {data: {controller: 'tinymce'}}
    end

    f.actions
  end
end
