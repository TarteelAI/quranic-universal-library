# frozen_string_literal: true

# == Schema Information
#
# Table name: juzs
#
#  id             :integer          not null, primary key
#  juz_number     :integer
#  verse_mapping  :json
#  verses_count   :integer
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  first_verse_id :integer
#  last_verse_id  :integer
#
# Indexes
#
#  index_juzs_on_first_verse_id  (first_verse_id)
#  index_juzs_on_juz_number      (juz_number)
#  index_juzs_on_last_verse_id   (last_verse_id)
#
ActiveAdmin.register Manzil do
  menu parent: 'Quran'
  actions :all, except: :destroy
  ActiveAdminViewHelpers.render_navigation_search_sidebar(self)

  filter :manzil_number
  filter :first_verse_id, as: :searchable_select,
         data: { controller: 'select2' },
         ajax: { resource: Verse }
  filter :last_verse_id, as: :searchable_select,
         data: { controller: 'select2' },
         ajax: { resource: Verse }
  filter :chapter_cont, as: :searchable_select,
         data: { controller: 'select2' },
         ajax: { resource: Chapter }

  def scoped_collection
    super.includes :first_verse, :last_verse
  end

  index do
    id_column
    column :manzil_number
    column :verses_count
    column :first_verse, sortable: :first_verse_id do |resource|
      resource.first_verse.verse_key
    end
    column :last_verse, sortable: :last_verse_id  do |resource|
      resource.last_verse.verse_key
    end

    actions
  end
end
