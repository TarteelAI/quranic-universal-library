# frozen_string_literal: true

ActiveAdmin.register VerseLemma do
  menu parent: 'Grammar'
  actions :all, except: :destroy
  permit_params :text_madani, :text_clean

  filter :text_madani
  filter :text_clean
end
