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
ActiveAdmin.register RawData::Resource do
  menu parent: 'Raw data'
  actions :all, except: :destroy

  searchable_select_options(
    scope: RawData::Resource,
    text_attribute: :name
  )

  filter :name

  permit_params do
    %i[name content_css_class lang_iso sub_type processed records_count]
  end

  index do
    id_column
    column :name
    column :lang_iso
    column :sub_type
    column :records_count
    column :processed

    actions
  end

  show do
    attributes_table do
      row :id
      row :name
      row :lang_iso
      row :sub_type
      row :records_count
      row :resource_content
      row :processed

      row :created_at
      row :updated_at
    end

    active_admin_comments

    panel "Resource data: (#{resource.records_count}) " do
      table do
        thead do
          td 'Id'
          td 'Ayah'
          td 'Text'
        end

        tbody do
          resource.ayah_records.includes(:verse).order('verse_id ASC').each do |r|
            tr do
              td link_to(r.id, [:admin, r])
              td r.verse.verse_key
              td truncate(r.text, length: 100)
            end
          end
        end
      end
    end

  end
end
