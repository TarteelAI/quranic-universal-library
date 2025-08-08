ActiveAdmin.register UloomContent do
  menu parent: 'Content'
  actions :all, except: [:destroy]

  includes :resource_content

  permit_params :text,
                :cardinality_type,
                :chapter_id,
                :verse_id,
                :word_id,
                :location,
                :resource_content_id,
                :location_range,
                :meta_data

  filter :resource_content,
         as: :searchable_select,
         ajax: { resource: ResourceContent }
  filter :chapter,
         as: :searchable_select,
         ajax: { resource: Chapter }
  filter :verse,
         as: :searchable_select,
         ajax: { resource: Verse }
  filter :word,
         as: :searchable_select,
         ajax: { resource: Word }
  filter :location
  filter :location_range
  filter :text

  index do
    id_column
    column :resource_content
    column :cardinality_type
    column :location
    column :location_range
    column :text do |uc|
      truncate(uc.text, length: 80)
    end
    actions
  end

  show do
    attributes_table do
      row :id
      row :chapter
      row :verse
      row :word
      row :resource_content
      row :cardinality_type
      row :location
      row :location_range
      row :text do |uc|
        uc.text.to_s.html_safe
      end
      row :meta_data do |uc|
        pre JSON.pretty_generate(uc.meta_data)
      end
      row :created_at
      row :updated_at
    end
  end

  form do |f|
    f.inputs 'UloomContent Details' do
      f.input :chapter,
              as: :searchable_select,
              ajax: { resource: Chapter }
      f.input :verse,
              as: :searchable_select,
              ajax: { resource: Verse }
      f.input :word,
              as: :searchable_select,
              ajax: { resource: Word }
      f.input :resource_content,
              as: :searchable_select,
              ajax: { resource: ResourceContent }
      f.input :cardinality_type, as: :select, collection: %w[word verse chapter]
      f.input :location
      f.input :location_range
      f.input :text, input_html: { rows: 5 }
      f.input :meta_data, as: :text, input_html: { rows: 3 }
    end
    f.actions
  end
end
