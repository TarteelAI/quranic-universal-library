# frozen_string_literal: true

ActiveAdmin.register UloomQuran::ByWord do
  menu parent: 'Content'
  actions :all, except: :destroy

  includes :chapter, :verse, :word, :resource_content

  filter :resource_content,
         as: :searchable_select,
         ajax: { resource: ResourceContent }
  filter :language,
         as: :searchable_select,
         ajax: { resource: Language }
  filter :chapter,
         as: :searchable_select,
         ajax: { resource: Chapter }
  filter :verse,
         as: :searchable_select,
         ajax: { resource: Verse }
  filter :word,
         as: :searchable_select,
         ajax: { resource: Word }
  filter :from,
         as: :numeric,
         label: 'Word From'
  filter :to,
         as: :numeric,
         label: 'Word To'

  filter :text
end
