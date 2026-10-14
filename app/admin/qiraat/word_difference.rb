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

  # The review queue (P6.3): a human says once, per word, whether the
  # spellings change the meaning; where they do, overrides are written per
  # spelling group through Qiraat::GlossOverride.
  scope :all
  scope('Needs decision', :needs_review)
  scope('Meaning may differ', :meaning_may_differ)
  scope :decided

  filter :chapter, as: :select, collection: -> { Chapter.order(:chapter_number).map { |c| ["#{c.chapter_number} #{c.name_simple}", c.id] } }
  filter :status, as: :select, collection: WordDifference::STATUSES
  filter :word_id, label: 'Word id'

  # font class per riwayah slug: the row-backed script of that riwayah, Hafs falls back to qpc-hafs
  font_for = lambda do |slug|
    return 'qpc-hafs' if slug == 'hafs'

    Script.row_backed.joins(:riwayah).find_by(riwayat: { slug: slug })&.font_css_class || 'qpc-hafs'
  end

  controller do
    helper_method :font_for_riwayah

    def font_for_riwayah(slug)
      return 'qpc-hafs' if slug == 'hafs'

      Script.row_backed.joins(:riwayah).find_by(riwayat: { slug: slug })&.font_css_class || 'qpc-hafs'
    end
  end

  # Write one override row per riwayah of a spelling group for a WBW resource.
  member_action :override, method: :post do
    rc = ResourceContent.find(params[:resource_content_id])
    rows = Qiraat::GlossOverride.new(resource, rc).apply(group: params[:group], text: params[:text], by: current_user.email)
    redirect_to cms_word_difference_path(resource, anchor: "gloss-resource-#{rc.id}"), notice: "Override written for #{rows.map { |r| r.riwayah.slug }.join(', ')} (#{rc.name})"
  rescue ArgumentError => e
    redirect_to cms_word_difference_path(resource), alert: e.message
  end

  member_action :remove_override, method: :delete do
    rc = ResourceContent.find(params[:resource_content_id])
    riwayah = Riwayah.find(params[:riwayah_id])
    Qiraat::GlossOverride.new(resource, rc).remove(riwayah, by: current_user.email)
    redirect_to cms_word_difference_path(resource, anchor: "gloss-resource-#{rc.id}"), notice: "#{riwayah.slug} override removed (#{rc.name})"
  end

  # Record the decision for the word (same_meaning, or back to the queue).
  member_action :decide, method: :put do
    decision = params[:decision].presence
    resource.decide!(decision, by: current_user.email, note: params[:note])
    redirect_to cms_word_difference_path(resource), notice: decision ? "Marked #{decision.humanize.downcase}" : 'Back in the queue'
  rescue ArgumentError => e
    redirect_to cms_word_difference_path(resource), alert: e.message
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
    column('Decision') { |d| d.decision ? status_tag(d.decision.humanize, class: d.decision == 'overridden' ? 'ok' : '') : status_tag('needs decision', class: 'warning') }
    column('Overrides') { |d| WordTranslation.overrides.where(word_id: d.word_id).count }
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
      row('Decision') do |d|
        if d.decision
          span "#{d.decision.humanize} — #{d.review['by']} #{d.review['at']}"
          span " · #{d.review['note']}", class: 'muted' if d.review['note'].present?
        else
          status_tag('needs decision', class: 'warning')
        end
      end
    end

    panel 'Spellings' do
      table_for resource.spelling_groups do
        column('Text') { |text, slugs| div(text, class: "quran-text #{font_for.call(slugs.first)}", style: 'font-size: 2em; direction: rtl') }
        column('Riwayat') { |_text, slugs| slugs.join(', ') }
      end
    end

    panel 'Glosses (word-by-word resources)' do
      render 'admin/qiraat/word_difference_glosses'
    end

    panel 'Decision' do
      render 'admin/qiraat/word_difference_decision'
    end
  end
end
