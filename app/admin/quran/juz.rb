# frozen_string_literal: true

ActiveAdmin.register Juz do
  menu parent: 'Quran'
  actions :all, except: :destroy
  filter :juz_number

  ActiveAdminViewHelpers.render_navigation_search_sidebar(self)
end
