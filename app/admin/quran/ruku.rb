# frozen_string_literal: true

ActiveAdmin.register Ruku do
  ActiveAdminViewHelpers.render_navigation_search_sidebar(self)
  menu parent: 'Quran'
  includes :first_verse, :last_verse

  actions :all, except: :destroy

  filter :ruku_number
  filter :surah_ruku_number
  filter :first_verse, as: :searchable_select,
         ajax: { resource: Verse }
  filter :last_verse, as: :searchable_select,
         ajax: { resource: Verse }
  filter :chapter_id_cont,
         as: :searchable_select,
         ajax: { resource: Chapter }

  index do
    id_column
    column :ruku_number
    column :surah_ruku_number
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
