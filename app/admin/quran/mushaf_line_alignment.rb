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
ActiveAdmin.register MushafLineAlignment do
  menu parent: 'Quran', priority: 1
  actions :all, except: :destroy

  filter :page_number
  filter :line_number
  filter :alignment
  filter :mushaf_id, as: :searchable_select,
                     ajax: { resource: Mushaf }

  def scoped_collection
    super.includes :mushaf
  end

  index do
    id_column
    column :mushaf
    column :line_number
    column :page_number
    column :alignment
    column :properties

    actions
  end

  show do
    attributes_table do
      row :id
      row :mushaf
      row :line_number
      row :page_number
      row :alignment
      row :properties

      row :created_at
      row :updated_at
    end
  end
end
