# frozen_string_literal: true

ActiveAdmin.register Juz do
  menu parent: 'Quran'
  actions :all, except: :destroy
  filter :juz_number
  filter :chapter_id_cont,
         as: :searchable_select,
         ajax: { resource: Chapter }

  ActiveAdminViewHelpers.render_navigation_search_sidebar(self)
end
