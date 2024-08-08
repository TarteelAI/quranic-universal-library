ActiveAdmin.register AyahTheme do
  menu parent: 'Content'

  filter :chapter, as: :searchable_select,
         ajax: { resource: Chapter }
  filter :theme

  actions :all, except: :destroy
  permit_params :chapter_id,
                :theme,
                :verse_id_from,
                :verse_id_to,
                :verse_key_from,
                :verse_key_to,
                :verse_number_from,
                :verse_number_to,
                :verses_count
end