# frozen_string_literal: true

ActiveAdmin.register RubElHizb do
  menu parent: 'Quran'
  actions :all, except: :destroy
  includes :first_verse, :last_verse

  ActiveAdminViewHelpers.render_navigation_search_sidebar(self)

  filter :rub_el_hizb_number
  filter :first_verse,
         as: :searchable_select,
         ajax: { resource: Verse }
  filter :last_verse, as: :searchable_select,
         ajax: { resource: Verse }

  filter :chapter_id_cont,
         as: :searchable_select,
         ajax: { resource: Chapter }

  index do
    id_column
    column :rub_el_hizb_number
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
