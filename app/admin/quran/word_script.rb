# frozen_string_literal: true

ActiveAdmin.register QuranScript::ByWord do
  menu parent: 'Quran'
  actions :all, except: :destroy

  includes :word,
           :verse,
           :resource_content

  filter :resource_content_id,
         as: :searchable_select,
         ajax: { resource: ResourceContent }
  filter :verse_id,
         as: :searchable_select,
         ajax: { resource: Verse }
  filter :word_id,
         as: :searchable_select,
         ajax: { resource: Word }
  filter :qirat_id,
         as: :searchable_select,
         ajax: { resource: QiratType }
  filter :key
  filter :text

  index do
    id_column

    column :resource_content
    column :qirat
    column :key
    column :text, sortable: :text do |resource|
      qirat_name = resource.qirat&.name
      div class: "quran-text qpc-#{qirat_name.to_s.downcase}" do
        resource.text.html_safe
      end
    end

    actions
  end

  show do
    attributes_table do
      row :id
      row :resource_content
      row :chapter
      row :verse
      row :word
      row :verse_number
      row :word_number
      row :key
      row :qirat

      row :text do |resource|
        qirat_name = resource.qirat&.name
        div class: "quran-text qpc-#{qirat_name.to_s.downcase}" do
          resource.text.html_safe
        end
      end
    end

    active_admin_comments
  end
end
