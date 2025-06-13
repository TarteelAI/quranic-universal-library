# frozen_string_literal: true

ActiveAdmin.register Author do
  menu parent: 'Settings'
  actions :all, except: :destroy

  searchable_select_options(
    scope: Author,
    text_attribute: :name
  )

  ActiveAdminViewHelpers.render_translated_name_sidebar(self)

  filter :name
  
  permit_params do
    %i[name url]
  end

  index do
    id_column
    column :name
    column :resource_contents_count
    actions
  end

  show do
    attributes_table do
      row :id
      row :name
      row :url
      row :resource_contents_count
      row :created_at
      row :updated_at
    end

    panel "Resources for this author (#{resource.resource_contents.size})" do
      table do
        thead do
          td 'ID'
          td 'Type'
          td 'Name'
          td 'Approved'
        end

        tbody do
          resource.resource_contents.each do |resource_content|
            tr do
              td link_to(resource_content.id, [:cms, resource_content])
              td resource_content.sub_type
              td resource_content.name
              td resource_content.approved?
            end
          end
        end
      end
    end

    active_admin_comments
  end
end
