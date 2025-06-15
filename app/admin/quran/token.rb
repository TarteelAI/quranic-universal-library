# frozen_string_literal: true

ActiveAdmin.register Token do
  menu parent: 'Quran'
  filter :record_id
  filter :record_type, as: :select, collection: %w[Word Verse]
  filter :resource_content, as: :searchable_select,
                            ajax: { resource: ResourceContent }

  index do
    id_column
    column :text_uthmani
    column :text_imlaei_simple
    column :uniq_token_count

    column :uniq_tokens do |resource|
      if resource.verse?
        #link_to resource.record_type, admin_verse_path(resource.record_id)
      else
        link_to resource.text_imlaei_simple, "/cms/words?q%5Btext_imlaei_simple_eq%5D=#{resource.text_imlaei_simple}&order=id_desc&commit=Filter"
      end
    end

    actions
  end
end
