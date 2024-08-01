# frozen_string_literal: true

ActiveAdmin.register VerseStem do
  menu parent: 'Grammar'
  actions :all, except: :destroy

  filter :text_clean
  filter :text_madani

  permit_params :text_madani, :text_clean
end
