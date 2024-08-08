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
        name_cont: term,
        m: 'or'
      ).result
    end
  )

  menu parent: 'Quran', priority: 1
  actions :all, except: %i[destroy new]

  permit_params do
    %i[name_simple name_arabic name_complex bismillah_pre revelation_order]
  end

  ActiveAdminViewHelpers.render_translated_name_sidebar(self)
  ActiveAdminViewHelpers.render_navigation_search_sidebar(self)
  ActiveAdminViewHelpers.render_slugs(self)

  filter :chapter_number
  filter :bismillah_pre
  filter :revelation_order
  filter :revelation_place
  filter :name_complex

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
  end

  index do
    column :chapter_number do |chapter|
      link_to chapter.id, admin_chapter_path(chapter)
    end
    column :bismillah_pre
    column :revelation_order
    column :revelation_place
    column :name_complex
    column :name_arabic
    column :pages
    column :verses_count
  end
end
