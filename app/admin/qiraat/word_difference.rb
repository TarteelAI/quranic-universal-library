# frozen_string_literal: true

# == Schema Information
#
# Table name: word_differences
#
#  chapter_id     :integer          not null
#  groups         :jsonb            not null
#  missing        :string           default([]), is an Array
#  review         :jsonb            not null
#  status         :string           not null
#  written_joined :string           default([]), is an Array
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  word_id        :integer          not null, primary key
#
ActiveAdmin.register WordDifference do
  menu parent: 'Qiraat', priority: 7, label: 'Word differences'
  actions :index, :show
  config.batch_actions = false
  config.sort_order = 'word_id_asc'

  includes :word, :chapter

  filter :chapter, as: :select, collection: -> { Chapter.order(:chapter_number).map { |c| ["#{c.chapter_number} #{c.name_simple}", c.id] } }
  filter :status, as: :select, collection: WordDifference::STATUSES
  filter :word_id, label: 'Word id'

  # font class per riwayah slug: the row-backed script of that riwayah, Hafs falls back to qpc-hafs
  font_for = lambda do |slug|
    return 'qpc-hafs' if slug == 'hafs'

    Script.row_backed.joins(:riwayah).find_by(riwayat: { slug: slug })&.font_css_class || 'qpc-hafs'
  end

  index download_links: false do
    column('Word') { |d| link_to d.word.location, cms_word_path(d.word) }
    column('Shared #') { |d| d.word.number }
    column :status
    column('Spellings') do |d|
      ul do
        d.spelling_groups.each do |text, slugs|
          li do
            span text, class: "quran-text #{font_for.call(slugs.first)}", style: 'font-size: 1.6em; direction: rtl; display: inline-block; min-width: 8em'
            span " #{slugs.join(', ')}", class: 'muted'
          end
        end
      end
    end
    column('Not read by') { |d| d.missing.join(', ') }
    column('Meaning may differ') { |d| d.meaning_may_differ? ? status_tag('check', class: 'warning') : '' }
    column('Review') { |d| d.review['decision'] || '' }
    actions
  end

  show do
    attributes_table do
      row(:word) { |d| link_to d.word.location, cms_word_path(d.word) }
      row('Shared number') { |d| d.word.number }
      row(:chapter) { |d| link_to d.chapter.name_simple, [:cms, d.chapter] }
      row :status
      row('Meaning may differ') { |d| d.meaning_may_differ? ? 'yes, review the gloss' : 'no (spelling only)' }
      row('Not read by') { |d| d.missing.join(', ').presence || 'read by all seven' }
      row('Written joined by') { |d| d.written_joined.join(', ') }
      row(:review) { |d| pre JSON.pretty_generate(d.review) }
    end

    panel 'Spellings' do
      table_for resource.spelling_groups do
        column('Text') { |text, slugs| div(text, class: "quran-text #{font_for.call(slugs.first)}", style: 'font-size: 2em; direction: rtl') }
        column('Riwayat') { |_text, slugs| slugs.join(', ') }
      end
    end
  end
end
