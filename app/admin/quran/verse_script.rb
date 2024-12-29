# frozen_string_literal: true

ActiveAdmin.register QuranScript::ByVerse do
  menu parent: 'Quran'
  actions :all, except: :destroy
  includes :verse, :resource_content

  filter :resource_content_id,
         as: :searchable_select,
         ajax: { resource: ResourceContent }
  filter :verse_id,
         as: :searchable_select,
         ajax: { resource: Verse }
  filter :qirat_id,
         as: :searchable_select,
         ajax: { resource: QiratType }
  filter :key
  filter :text
end
