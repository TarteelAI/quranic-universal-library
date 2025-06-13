# frozen_string_literal: true

# == Schema Information
#
# Table name: authors
#
#  id         :integer          not null, primary key
#  name       :string
#  url        :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
ActiveAdmin.register Tag do
  menu parent: 'Settings'

  searchable_select_options(
    scope: Tag,
    text_attribute: :name
  )

  filter :name

  permit_params do
    %i[name description]
  end

  index do
    id_column
    column :name
    column :resources_count

    actions
  end

  show do
    attributes_table do
      row :id
      row :name
      row :resources_count
      row :description
      row :created_at
      row :updated_at
    end

    panel "Resources for this tag (#{resource.resources.size})" do
      table do
        thead do
          td 'Id'
          td 'Type'
          td 'Language'
          td 'Name'
        end

        tbody do
          resource.resources.each do |r|
            tr do
              td link_to(r.id, [:cms, r])
              td r.sub_type
              td r.language_name
              td r.name
            end
          end
        end
      end
    end

    active_admin_comments
  end
end
