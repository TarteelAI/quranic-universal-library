# frozen_string_literal: true

ActiveAdmin.register WordSynonym do
  menu parent: 'Settings'
  actions :index, :show

  filter :word,
         as: :searchable_select,
         ajax: { resource: Word }
  filter :synonym_id
end
