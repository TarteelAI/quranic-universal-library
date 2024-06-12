# frozen_string_literal: true

ActiveAdmin.register VerseLemma do
  menu parent: 'Grammar'
  actions :all, except: :destroy

  filter :text_madani
  filter :text_clean
end
