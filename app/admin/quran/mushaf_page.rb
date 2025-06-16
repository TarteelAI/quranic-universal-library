# frozen_string_literal: true

ActiveAdmin.register MushafPage do
  menu parent: 'Quran', priority: 1
  actions :all, except: :destroy
  includes :mushaf
  filter :page_number
  filter :lines_count
  filter :mushaf,
         as: :searchable_select,
         ajax: { resource: Mushaf }

  ActiveAdminViewHelpers.render_navigation_search_sidebar(self)

  permit_params do
    %i[page_number verses_count first_verse_id last_verse_id mushaf_id lines_count]
  end

  action_item :preview, only: :show do
    link_to 'Preview Page', "/cms/mushaf_page_preview?page=#{resource.page_number}&mushaf=#{resource.mushaf_id}",
            class: 'btn'
  end

  index do
    id_column
    column :chapter_id
    column :mushaf
    column :verses_count
    column :page_number
    column :lines_count
    column :verses, &:verse_mapping

    actions
  end

  form do |f|
    f.inputs do
      f.input :mushaf,
              as: :searchable_select,
              ajax: { resource: Mushaf }

      f.input :page_number
      f.input :verse_mapping
      f.input :verses_count
      f.input :lines_count
      f.input :first_verse_id
      f.input :first_verse_id,
              as: :searchable_select,
              ajax: { resource: Verse }
      f.input :last_verse_id,
              as: :searchable_select,
              ajax: { resource: Verse }
    end

    f.actions
  end

  show do
    words = resource.words

    attributes_table do
      row :id
      row :page_number
      row :lines_count
      row :verse_mapping
      row :mushaf

      row :first_verse do |r|
        if r.first_verse
          link_to r.first_verse.verse_key, [:cms, r.first_verse]
        end
      end

      row :last_verse do |r|
        if r.last_verse
          link_to r.last_verse.verse_key, [:cms, r.last_verse]
        end
      end

      row :first_word do |r|
        if r.first_word
          link_to "#{r.first_word.location}(#{r.first_word.text_uthmani_simple})", [:cms, r.first_word]
        end
      end

      row :last_word do |r|
        if r.last_word
          link_to "#{r.last_word.location}(#{r.last_word.text_uthmani_simple})", [:cms, r.last_word]
        end
      end

      row :words_count do
        words.size
      end
      row :created_at
      row :updated_at
    end

    div class: 'mushaf-layout' do
      render 'shared/mushaf_page',
             words: words,
             page: resource.page_number,
             mushaf: resource.mushaf,
             name: resource.mushaf.name
    end
  end
end
