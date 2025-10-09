# frozen_string_literal: true

# == Schema Information
#
# Table name: chapters
#
#  id               :integer          not null, primary key
#  bismillah_pre    :boolean
#  chapter_number   :integer
#  name_arabic      :string
#  name_complex     :string
#  name_simple      :string
#  pages            :string
#  revelation_order :integer
#  revelation_place :string
#  verses_count     :integer
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#
# Indexes
#
#  index_chapters_on_chapter_number  (chapter_number)
#
ActiveAdmin.register Chapter do
  searchable_select_options(
    scope: Chapter,
    text_attribute: :humanize,
    filter: lambda do |term, scope|
      scope.order('id ASC').ransack(
        chapter_number_eq: term,
        name_simple_cont: term,
        name_arabic_cont: term,
        m: 'or'
      ).result
    end
  )

  menu parent: 'Quran', priority: 1
  actions :all, except: %i[destroy new]

  permit_params do
    %i[
      name_simple
      name_arabic
      name_complex
      bismillah_pre
      revelation_order
      v1_chapter_glyph_code
      v4_chapter_glyph_code
      color_header_chapter_glyph_code
   ]
  end

  ActiveAdminViewHelpers.render_translated_name_sidebar(self)
  ActiveAdminViewHelpers.render_navigation_search_sidebar(self)
  ActiveAdminViewHelpers.render_slugs(self)

  filter :chapter_number
  filter :bismillah_pre
  filter :revelation_order
  filter :revelation_place
  filter :name_complex
  filter :name_simple
  filter :name_arabic

  show do
    attributes_table do
      row :id
      row :chapter_number
      row :bismillah_pre
      row :revelation_order
      row :revelation_place
      row :name_simple
      row :name_complex
      row :name_arabic
      row :pages
      row :verses_count
    end

    panel 'Chapter names font preview' do
      attributes_table_for chapter do
        row :v1_chapter_glyph_code do
          div "#{chapter.v1_chapter_glyph_code} surah-icon", class: 'surah-name-v1-icon'
        end
        row :v2_chapter_glyph_code do
          div chapter.v2_chapter_glyph_code, class: 'surah-name-v2-icon'
        end
        row :v4_chapter_glyph_code do
          div "#{chapter.v4_chapter_glyph_code} surah-icon", class: 'surah-name-v4-icon'
        end
        row :color_header_chapter_glyph_code do
          div chapter.color_header_chapter_glyph_code, class: 'surah-header-icon'
        end
      end
    end
  end

  index do
    column :chapter_number do |chapter|
      link_to chapter.id, cms_chapter_path(chapter)
    end
    column :bismillah_pre
    column :revelation_order
    column :revelation_place
    column :name_simple
    column :name_complex
    column :name_arabic
    column :pages
    column :verses_count
  end

  form do |f|
    f.semantic_errors *f.object.errors

    f.inputs 'Chapter Details' do
      f.input :bismillah_pre
      f.input :revelation_order
      f.input :revelation_place, as: :select, collection: Chapter.revelation_places.map { |place| [place.titleize, place] }
      f.input :name_simple
      f.input :name_complex
      f.input :name_arabic

      f.input :v1_chapter_glyph_code, as: :string
      f.input :v2_chapter_glyph_code, as: :string
      f.input :v4_chapter_glyph_code, as: :string
      f.input :color_header_chapter_glyph_code, as: :string
    end

    f.actions
  end
end
