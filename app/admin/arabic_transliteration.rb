# frozen_string_literal: true

# == Schema Information
#
# Table name: arabic_transliterations
#
#  id             :integer          not null, primary key
#  continuous     :boolean
#  indopak_text   :string
#  page_number    :integer
#  position_x     :integer
#  position_y     :integer
#  text           :string
#  ur_translation :string
#  zoom           :float
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  verse_id       :integer
#  word_id        :integer
#
# Indexes
#
#  index_arabic_transliterations_on_verse_id  (verse_id)
#  index_arabic_transliterations_on_word_id   (word_id)
#
ActiveAdmin.register ArabicTransliteration do
  menu parent: 'Content', priority: 10
  actions :all, except: :destroy

  ActiveAdminViewHelpers.versionate(self)

  index do
    id_column
    column :verse_id
    column :word_id
    column :text
    column :indopak_text
    actions
  end

  form do |f|
    render 'shared/keyboard_assets'
    f.inputs 'ArabicTransliteration detail' do
      f.input :verse_id
      f.input :word_id
      f.input :text, as: :text, field_html: { class: 'transliteration' }
      f.input :indopak_text, as: :text
    end
    f.actions
  end

  permit_params do
    %i[resource_type resource_id url duration segments recitation_id]
  end
end
