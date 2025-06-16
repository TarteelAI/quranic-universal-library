# frozen_string_literal: true

ActiveAdmin.register MushafWord do
  menu parent: 'Quran'
  actions :all, except: %i[destroy new]
  includes :word, :mushaf, :char_type

  filter :mushaf
  filter :char_type
  filter :word, as: :searchable_select,
         ajax: { resource: Word }
  filter :verse, as: :searchable_select,
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
            div do
              div resource.text.to_s.html_safe, class: "quran-text "
              div link_to('Chars', "/community/chars_info?text=#{resource.text}&name=#{[resource.mushaf.name, resource.word.location].join('-')}", target: '_blank', class: 'fs-sm')
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
                "/cms/mushaf_page_preview?mushaf=#{resource.mushaf_id}&page=#{resource.page_number}&word=#{resource.word_id}"
      end
      row :position_in_line
      row :position_in_page
      row :position_in_verse
    end
  end
end
