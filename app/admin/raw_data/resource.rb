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
    %i[name content_css_class lang_iso sub_type processed records_count resource_content_id]
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
  end

  form do |f|
    f.inputs 'Resource detail' do
      f.input :name
      f.input :content_css_class

      f.input :resource_content_id,
              as: :searchable_select,
              ajax: { resource: ResourceContent }

      f.input :meta_data, input_html: { data: { controller: 'json-editor', json: resource.meta_data } }
    end

    f.actions
  end

end
