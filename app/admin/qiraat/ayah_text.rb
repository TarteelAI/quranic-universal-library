# frozen_string_literal: true

# == Schema Information
#
# Table name: ayah_texts
#
#  text      :text             not null
#  ayah_id   :integer          not null, primary key
#  script_id :integer          not null, primary key
#
# Composite key, index-only. Filled per numbering in phase 4.
ActiveAdmin.register AyahText do
  menu parent: 'Qiraat', priority: 6, label: 'Ayah texts'
  actions :index
  config.batch_actions = false
  config.sort_order = 'ayah_id_asc'

  includes :script

  filter :script, as: :select, collection: -> { Script.row_backed.order(:slug).map { |s| [s.slug, s.id] } }
  filter :ayah_id
  filter :text

  index download_links: false do
    column('Script') { |t| link_to t.script.slug, cms_script_path(t.script) }
    column :ayah_id
    column('Text') { |t| div(t.text, class: "quran-text #{t.script.font_css_class}", style: 'direction: rtl') }
  end
end
