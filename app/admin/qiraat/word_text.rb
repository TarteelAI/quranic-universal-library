# frozen_string_literal: true

# == Schema Information
#
# Table name: word_texts
#
#  marks       :jsonb            not null
#  text        :text             not null
#  text_simple :text
#  script_id   :integer          not null, primary key
#  word_id     :integer          not null, primary key
#
# Composite key, so this is an index-only resource: rows are edited through
# the importer (rake qiraat:import:script), never by hand.
ActiveAdmin.register WordText do
  menu parent: 'Qiraat', priority: 5, label: 'Word texts'
  actions :index
  config.batch_actions = false
  config.sort_order = 'word_id_asc'

  includes :script, :word

  filter :script, as: :select, collection: -> { Script.row_backed.order(:slug).map { |s| [s.slug, s.id] } }
  filter :word_id, label: 'Word id'
  filter :word_number, as: :numeric, label: 'Shared number'
  filter :word_verse_key, as: :string, label: 'Verse key'
  filter :text

  index download_links: false do
    column('Script') { |t| link_to t.script.slug, cms_script_path(t.script) }
    column('Word') { |t| link_to t.word.location, cms_word_path(t.word) }
    column('Shared #') { |t| t.word.number }
    column('Text') { |t| div(t.text, class: "quran-text #{t.script.font_css_class}", style: 'direction: rtl') }
    column('Marks') { |t| t.marks.join(' ') }
    column('Hafs (qpc-hafs)') { |t| div(t.word.text_qpc_hafs, class: 'quran-text qpc-hafs', style: 'direction: rtl') }
  end
end
