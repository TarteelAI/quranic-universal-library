# frozen_string_literal: true

ActiveAdmin.register UloomQuran::ByVerse do
  menu parent: 'Content'
  actions :all, except: :destroy

  includes :chapter, :verse, :resource_content

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
  filter :from,
         as: :numeric,
         label: 'Verse From'
  filter :to,
         as: :numeric,
         label: 'Verse To'

  filter :text
end
