# frozen_string_literal: true

# == Schema Information
#
# Table name: mushaf_words
#
#  id                :bigint           not null, primary key
#  char_type_name    :string
#  css_class         :string
#  css_style         :string
#  line_number       :integer
#  page_number       :integer
#  position_in_line  :integer
#  position_in_page  :integer
#  position_in_verse :integer
#  text              :text
#  char_type_id      :integer
#  mushaf_id         :integer
#  verse_id          :integer
#  word_id           :integer
#
# Indexes
#
#  index_mushaf_words_on_mushaf_id_and_word_id  (mushaf_id,word_id)
#  index_on_mushad_word_position                (mushaf_id,verse_id,position_in_verse)
#  index_on_mushaf_word_position                (mushaf_id,verse_id,position_in_page)
#
ActiveAdmin.register MushafWord do
  menu parent: 'Quran'
  actions :all, except: %i[destroy new]

  filter :mushaf
  filter :char_type
  filter :word, as: :searchable_select,
         ajax: { resource: Word }
  filter :verse_id, as: :searchable_select,
         ajax: { resource: Verse }
  filter :line_number
  filter :page_number

  permit_params do
    %i[
      mushaf_id
      verse_id
      word_id
      text
      char_type_id
      line_number
      page_number
      position_in_line
      position_in_page
      css_class
      css_style
    ]
  end

  form do |f|
    f.inputs 'Mushaf Word Mapping' do
      f.input :mushaf_id
      f.input :verse_id,
              as: :searchable_select,
              ajax: { resource: Verse }
      f.input :word_id,
              as: :searchable_select,
              ajax: { resource: Word }

      f.input :text
      f.input :char_type

      f.input :css_class
      f.input :css_style

      f.input :line_number
      f.input :page_number
      f.input :position_in_verse
      f.input :position_in_line
      f.input :position_in_page
    end
    f.actions
  end

  show do
    attributes_table do
      row :id
      row :word
      row :mushaf
      row :verse
      row :text do
        div class: resource.mushaf.default_font_name do
          if resource.mushaf.use_images?
            render 'shared/tajweed_image', word: resource
          else
            div class: "quran-text " do
              resource.text.to_s.html_safe
            end
          end
        end
      end

      row :css_class
      row :css_style

      row :char_type
      row :line_number
      row :page_number do
        link_to resource.page_number,
                "/admin/mushaf_page_preview?mushaf=#{resource.mushaf_id}&page=#{resource.page_number}&word=#{resource.word_id}"
      end
      row :position_in_line
      row :position_in_page
      row :position_in_verse
    end
  end

  def scoped_collection
    super.includes :word, :mushaf, :char_type
  end
end
