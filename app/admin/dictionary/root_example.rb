# frozen_string_literal: true

ActiveAdmin.register Dictionary::RootExample do
  menu parent: 'Dictionary'
  includes :word_root
  filter :verse,
         as: :searchable_select,
         ajax: { resource: Verse }

  filter :word,
         as: :searchable_select,
         ajax: { resource: Word }

  filter :word_root,
         as: :searchable_select,
         ajax: { resource: Dictionary::WordRoot }

  permit_params do
    %i[
      segment_arabic
      segment_first_word_timestamp
      segment_last_word_timestamp
      segment_translation
      word_arabic
      word_translation
      segment_first_word_id
      segment_last_word_id
      word_id
      word_root_id
    ]
  end

  form do |f|
    f.inputs 'Root word example detail' do
      f.input :word,
              as: :searchable_select,
              ajax: { resource: Word }

      f.input :word_root,
              as: :searchable_select,
              ajax: { resource: Dictionary::WordRoot }

      f.input :word_arabic
      f.input :word_translation

      f.input :segment_arabic
      f.input :segment_translation

      f.input :segment_first_word,
              as: :searchable_select,
              ajax: { resource: Word }
      f.input :segment_last_word,
              as: :searchable_select,
              ajax: { resource: Word }
    end
    f.actions
  end

  index do
    id_column
    column :word_root do |item|
      link_to(item.word_root.arabic_trilateral, [:cms, item.word_root])
    end

    column :word_arabic
    column :word_translation
  end
end
