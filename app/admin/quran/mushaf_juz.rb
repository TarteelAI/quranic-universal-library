# frozen_string_literal: true

# == Schema Information
#
# Table name: mushaf_pages
#
#  id             :bigint           not null, primary key
#  page_number    :integer
#  verse_mapping  :json
#  verses_count   :integer
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  first_verse_id :integer
#  first_word_id  :integer
#  last_verse_id  :integer
#  last_word_id   :integer
#  mushaf_id      :integer
#
# Indexes
#
#  index_mushaf_pages_on_mushaf_id    (mushaf_id)
#  index_mushaf_pages_on_page_number  (page_number)
#
ActiveAdmin.register MushafJuz do
  menu parent: 'Quran', priority: 1
  actions :all, except: :destroy

  filter :juz_number
  filter :mushaf_id, as: :searchable_select,
                     ajax: { resource: Mushaf }

  permit_params do
    %i[juz_number verses_count first_verse_id last_verse_id mushaf_id]
  end

  def scoped_collection
    super.includes :mushaf
  end

  index do
    id_column
    column :mushaf
    column :juz_number
    column :verses_count
    column :verses, &:verse_mapping

    actions
  end

  form do |f|
    f.inputs do
      f.input :mushaf,
              as: :searchable_select,
              ajax: { resource: Mushaf }

      f.input :juz_number
      f.input :verse_mapping
      f.input :verses_count
      f.input :first_verse_id
      f.input :first_verse_id,
              as: :searchable_select,
              ajax: { resource: Verse }
      f.input :last_verse_id,
              as: :searchable_select,
              ajax: { resource: Verse }
    end

    f.actions
  end

  show do
    attributes_table do
      row :id
      row :juz_number
      row :verse_mapping
      row :first_verse
      row :last_verse
      row :mushaf
      row :juz
      row :created_at
      row :updated_at
    end
  end
end
