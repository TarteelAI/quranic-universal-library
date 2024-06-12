# frozen_string_literal: true

ActiveAdmin.register VerseRoot do
  menu parent: 'Grammar'
  actions :all, except: :destroy

  filter :value
end
