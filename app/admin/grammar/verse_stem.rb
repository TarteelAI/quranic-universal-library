# frozen_string_literal: true

ActiveAdmin.register VerseStem do
  menu parent: 'Grammar'
  actions :all, except: :destroy

  filter :text_clean
end
