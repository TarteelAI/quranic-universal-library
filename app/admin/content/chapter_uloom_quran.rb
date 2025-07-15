# frozen_string_literal: true

ActiveAdmin.register UloomQuran::ByChapter do
  menu parent: 'Content'
  actions :all, except: :destroy

  includes :chapter, :resource_content

  filter :resource_content,
         as: :searchable_select,
         ajax: { resource: ResourceContent }
  filter :language,
         as: :searchable_select,
         ajax: { resource: Language }
  filter :chapter,
         as: :searchable_select,
         ajax: { resource: Chapter }


  filter :text
end
