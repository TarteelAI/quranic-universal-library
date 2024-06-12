# frozen_string_literal: true

# == Schema Information
#
# Table name: dictionary_root_examples
#
#  id                           :bigint           not null, primary key
#  segment_arabic               :string
#  segment_first_word_timestamp :integer
#  segment_last_word_timestamp  :integer
#  segment_translation          :string
#  word_arabic                  :string
#  word_translation             :string
#  created_at                   :datetime         not null
#  updated_at                   :datetime         not null
#  segment_first_word_id        :integer
#  segment_last_word_id         :integer
#  verse_id                     :integer
#  word_id                      :integer
#  word_root_id                 :bigint
#
# Indexes
#
#  index_dictionary_root_examples_on_verse_id  (verse_id)
#  index_dictionary_root_examples_on_word_id   (word_id)
#  index_on_dict_word_example_id               (word_root_id)
#
ActiveAdmin.register Dictionary::RootExample do
  menu parent: 'Dictionary'

  filter :verse_id, as: :searchable_select,
                    ajax: { resource: Verse }

  filter :word_id, as: :searchable_select,
                   ajax: { resource: Word }

  filter :word_root_id, as: :searchable_select,
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

  def scoped_collection
    super.includes :word_root
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
      link_to(item.word_root.arabic_trilateral, [:admin, item.word_root])
    end

    column :word_arabic
    column :word_translation
  end
end
