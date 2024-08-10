# frozen_string_literal: true

ActiveAdmin.register DataSource do
  menu parent: 'Content'
  actions :all, except: :destroy
  filter :name
  filter :url

  permit_params :name, :url, on: :data_source
  searchable_select_options(
    scope: DataSource,
    text_attribute: :name
  )

  show do
    attributes_table do
      row :id
      row :name
      row :url
    end

    panel 'Resources from this source' do
      table do
        thead do
          td 'ID'
          td 'Type'
          td 'Name'
        end

        tbody do
          resource.resource_contents.each do |resource_content|
            tr do
              td link_to(resource_content.id, [:admin, resource_content])
              td resource_content.sub_type
              td resource_content.name
            end
          end
        end
      end
    end

    active_admin_comments
  end
end
