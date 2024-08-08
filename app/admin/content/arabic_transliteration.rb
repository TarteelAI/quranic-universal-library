# frozen_string_literal: true

ActiveAdmin.register ArabicTransliteration do
  menu parent: 'Content', priority: 10

  actions :index, :show
  filter :verse, as: :searchable_select,
         ajax: { resource: Verse }
  filter :word, as: :searchable_select,
         ajax: { resource: Word }
  filter :text

  ActiveAdminViewHelpers.versionate(self)

  index do
    id_column
    column :verse_id
    column :word_id
    column :text
    column :indopak_text
    actions
  end
end
