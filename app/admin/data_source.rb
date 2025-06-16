# frozen_string_literal: true

ActiveAdmin.register DataSource do
  menu parent: 'Content'
  actions :all, except: :destroy
  filter :name
  filter :url
  filter :resource_count

  permit_params :name, :url, :description, on: :data_source
  searchable_select_options(
    scope: DataSource,
    text_attribute: :name
  )

  show do
    attributes_table do
      row :id
      row :name
      row :url
      row :description
      row :resource_count
    end

    panel 'Resources from this source' do
      table do
        thead do
          td 'ID'
          td 'Name'
          td 'Language'
          td 'Cardinality'
          td 'Approved?'
        end

        tbody do
          resource.grouped_resources_on_type.each_with_index do |(resource_type, records), index|
            tr class: "group-header", 'data-target': "group-#{index}" do
              td colspan: 5do
                h3 "#{resource_type.humanize} - #{records.size}"
              end
            end

            records.each do |resource_content|
              tr class: "group-rows group-#{index}" do
                td link_to(resource_content.id, [:cms, resource_content])
                td resource_content.name
                td resource_content.language_name
                td resource_content.cardinality_type
                td resource_content.approved?
              end
            end
          end
        end
      end
    end

    active_admin_comments
  end
end
