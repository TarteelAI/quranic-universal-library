# frozen_string_literal: true

ActiveAdmin.register Morphology::DerivedWord do
  menu parent: 'Morphology'
  actions :index, :show
  includes :verse

  filter :verse_id, as: :numeric
  filter :word_id, as: :numeric
  filter :derived_word_id, as: :numeric
  filter :form_name
  filter :en_translation
  filter :en_transliteration

  index do
    id_column
    column :verse do |resource|
      resource.verse && link_to(resource.verse.verse_key, [:cms, resource.verse])
    end
    column :word_id
    column :derived_word_id
    column :form_name
    column :en_transliteration
    column :en_translation
    actions
  end

  show do
    attributes_table do
      row :id
      row :verse do |resource|
        resource.verse && link_to(resource.verse.verse_key, [:cms, resource.verse])
      end
      row :word_id
      row :derived_word do |resource|
        resource.derived_word && link_to(resource.derived_word.location, [:cms, resource.derived_word])
      end
      row :word_verb_from
      row :form_name
      row :en_transliteration
      row :en_translation
      row :created_at
      row :updated_at
    end
  end
end
