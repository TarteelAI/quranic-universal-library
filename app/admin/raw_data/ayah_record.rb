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
ActiveAdmin.register RawData::AyahRecord do
  menu parent: 'Raw data'
  actions :all, except: :destroy

  filter :resource
  filter :verse,
         as: :searchable_select,
         ajax: { resource: Verse }

  permit_params do
    %i[name url]
  end

  index do
    id_column
    column :verse, sortable: :verse_id
    column :resource
    column :processed
    column :text_cleaned do |resource|
      resource.text&.first(50)
    end

    actions
  end

  show do
    attributes_table do
      row :id
      row :resource
      row :processed
      row :verse
      row :records_count
      row :text_preview do |resource|
        div resource.text.to_s.html_safe, class: resource.content_css_class.to_s
      end

      row :text_cleaned do |resource|
        div resource.text_cleaned.to_s.html_safe, class: resource.content_css_class.to_s
      end

      row :created_at
      row :updated_at
    end

    active_admin_comments
  end

  form do |f|
    f.inputs 'Ayah content detail' do
      f.input :verse_id,
              as: :searchable_select,
              ajax: { resource: Verse }

      f.input :resource_id,
              as: :searchable_select,
              ajax: { resource: RawData::Resource }

      f.input :text
      f.input :text_cleaned, input_html: { data: { controller: 'tinymce' } }
    end

    f.actions
  end
end
