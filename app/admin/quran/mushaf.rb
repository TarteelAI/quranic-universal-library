# frozen_string_literal: true

ActiveAdmin.register Mushaf do
  menu parent: 'Quran', priority: 1

  searchable_select_options(
    scope: Mushaf,
    text_attribute: :name
  )

  actions :all, except: :destroy

  filter :name
  filter :enabled
  filter :pages_count
  filter :lines_per_page
  filter :qirat_type,
         as: :searchable_select,
         ajax: { resource: QiratType }

  permit_params do
    %i[name description lines_per_page is_default default_font_name enabled default_font_name qirat_type_id pages_count
       resource_content_id]
  end

  index do
    id_column
    column :name
    column :lines_per_page
    column :pages_count
    column :enabled
    column :default_font_name
    column :qirat_type
  end

  show do
    attributes_table do
      row :id
      row :name
      row :description
      row :qirat_type
      row :resource_content
      row :default_font_name
      row :enabled
      row :is_default
      row :lines_per_page
      row :pages_count
      row :pdf_url
      row :created_at
      row :updated_at
    end

    active_admin_comments

    panel 'Preview any page of this Mushaf' do
      div class: 'placeholder' do
        h4 'Select page'

        ul do
          1.upto resource.pages_count do |p|
            li link_to("Page #{p}", "/admin/mushaf_page_preview?page=#{p}&mushaf=#{resource.id}")
          end
        end
      end
    end
  end

  form do |f|
    f.inputs do
      f.input :name
      f.input :is_default
      f.input :enabled
      f.input :description
      f.input :lines_per_page
      f.input :pages_count
      f.input :default_font_name
      f.input :qirat_type,
              as: :searchable_select,
              ajax: { resource: QiratType }

      f.input :resource_content_id, as: :searchable_select,
              ajax: { resource: ResourceContent }
    end

    f.actions
  end
end
