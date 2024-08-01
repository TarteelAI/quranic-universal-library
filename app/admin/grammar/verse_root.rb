# frozen_string_literal: true

ActiveAdmin.register VerseRoot do
  menu parent: 'Grammar'
  actions :all, except: :destroy
  permit_params :value

  filter :value
end
