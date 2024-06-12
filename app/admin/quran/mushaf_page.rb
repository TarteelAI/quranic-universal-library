# frozen_string_literal: true

# == Schema Information
#
# Table name: mushaf_pages
#
#  id             :bigint           not null, primary key
#  page_number    :integer
#  verse_mapping  :json
#  verses_count   :integer
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  first_verse_id :integer
#  first_word_id  :integer
#  last_verse_id  :integer
#  last_word_id   :integer
#  mushaf_id      :integer
#
# Indexes
#
#  index_mushaf_pages_on_mushaf_id    (mushaf_id)
#  index_mushaf_pages_on_page_number  (page_number)
#
ActiveAdmin.register MushafPage do
  menu parent: 'Quran', priority: 1
  actions :all, except: :destroy

  filter :page_number
  filter :mushaf_id, as: :searchable_select,
                     ajax: { resource: Mushaf }

  ActiveAdminViewHelpers.render_navigation_search_sidebar(self)

  permit_params do
    %i[page_number verses_count first_verse_id last_verse_id mushaf_id]
  end

  action_item :preview, only: :show do
    link_to 'Preview Page', "/admin/mushaf_page_preview?page=#{resource.page_number}&mushaf=#{resource.mushaf_id}",
            class: 'btn'
  end

  def scoped_collection
    super.includes :mushaf
  end

  index do
    id_column
    column :chapter_id
    column :mushaf
    column :verses_count
    column :page_number
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
      row :verse_mapping
      row :mushaf

      row :first_verse do |r|
        if r.first_verse
          link_to r.first_verse.verse_key, [:admin, r.first_verse]
        end
      end

      row :last_verse do |r|
        if r.last_verse
          link_to r.last_verse.verse_key, [:admin, r.last_verse]
        end
      end

      row :first_word do |r|
        if r.first_word
          link_to "#{r.first_word.location}(#{r.first_word.text_uthmani_simple})", [:admin, r.first_word]
        end
      end

      row :last_word do |r|
        if r.last_word
          link_to "#{r.last_word.location}(#{r.last_word.text_uthmani_simple})", [:admin, r.last_word]
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
