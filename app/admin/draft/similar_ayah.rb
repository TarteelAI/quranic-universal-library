# frozen_string_literal: true

ActiveAdmin.register Draft::SimilarAyah do
  menu parent: 'Drafts', label: 'Draft Similar Ayahs'

  filter :chapter_id, as: :select, collection: -> { (1..114).to_a }
  filter :verse_id
  filter :need_review
  filter :imported

  includes :user, :verse

  scope :all, default: true
  scope :pending_contributions

  action_item :review, only: :show do
    unless resource.imported?
      label = resource.need_review? ? 'Mark approved' : 'Mark for review'
      link_to label, review_cms_draft_similar_ayah_path(resource), method: :put
    end
  end

  action_item :import, only: :show do
    unless resource.imported?
      link_to 'Approve and update', import_cms_draft_similar_ayah_path(resource), method: :put, data: { confirm: 'Are you sure?' }
    end
  end

  member_action :review, method: 'put' do
    resource.update_columns(need_review: !resource.need_review?)

    redirect_to cms_draft_similar_ayah_path(resource),
                notice: resource.need_review? ? 'Marked for review' : 'Marked approved'
  end

  member_action :import, method: 'put' do
    resource.import!

    redirect_to cms_draft_similar_ayah_path(resource), notice: 'Draft similar ayahs are approved and imported successfully'
  end

  index do
    id_column
    column :ayah do |draft|
      link_to draft.verse.verse_key, similar_ayah_path(draft.verse_id)
    end
    column :changed do |draft|
      parts = []
      parts << "add #{draft.added_verses.pluck(:verse_key).join(', ')}" if draft.added_verse_ids.any?
      parts << "remove #{draft.removed_verses.pluck(:verse_key).join(', ')}" if draft.removed_verse_ids.any?
      parts << "both ways #{draft.both_ways_verses.pluck(:verse_key).join(', ')}" if draft.both_ways_verse_ids.any?
      parts.any? ? parts.join('; ') : span('no change', class: 'status_tag')
    end
    column :status do |draft|
      status_tag draft.status, class: { 'imported' => 'yes', 'approved' => 'yes', 'needs review' => 'no' }[draft.status]
    end
    column :comment do |draft|
      draft.comment.to_s.truncate(80)
    end
    column :user
    column :created_at

    actions
  end

  show do
    ayahs = lambda do |verses|
      table_for verses do
        column(:ayah) { |verse| link_to verse.verse_key, similar_ayah_path(verse.id) }
        column(:text) { |verse| div verse.text_qpc_hafs, class: 'qpc-hafs', dir: 'rtl' }
      end
    end

    attributes_table title: 'Suggestion' do
      row :ayah do
        link_to resource.verse.verse_key, similar_ayah_path(resource.verse_id)
      end
      row :text do
        div resource.verse.text_qpc_hafs, class: 'qpc-hafs', dir: 'rtl'
      end
      row :user
      row :comment do
        resource.comment.presence || span('No comment', class: 'status_tag')
      end
      row :status do
        status_tag resource.status, class: resource.need_review? && !resource.imported? ? 'no' : 'yes'
      end
      row :created_at
    end

    if resource.added_verse_ids.any?
      panel 'Ayahs to add' do
        ayahs.call(resource.added_verses)
      end
    end

    if resource.removed_verse_ids.any?
      panel 'Ayahs to remove' do
        ayahs.call(resource.removed_verses)
      end
    end

    if resource.both_ways_verse_ids.any?
      panel "Also list #{resource.verse.verse_key} as similar to these ayahs" do
        para "Only the ones that score #{Draft::SimilarAyah::BOTH_WAYS_MIN_SCORE} or more are listed."
        ayahs.call(resource.both_ways_verses)
      end
    end

    if resource.meta_data['both_ways_skipped'].present?
      panel 'Not listed both ways, the score was too low' do
        ayahs.call(Verse.where(id: resource.meta_data['both_ways_skipped']).order(:verse_index))
      end
    end

    others = Draft::SimilarAyah.where(verse_id: resource.verse_id).where.not(id: resource.id).order(id: :desc)
    if others.any?
      panel 'Other suggestions for this ayah' do
        table_for others do
          column(:id) { |d| link_to d.id, cms_draft_similar_ayah_path(d) }
          column(:status) { |d| d.status }
          column :user
          column(:comment) { |d| d.comment.to_s.truncate(80) }
          column :created_at
        end
      end
    end
  end

  form do |f|
    f.inputs 'Suggestion' do
      f.input :need_review, hint: 'Untick to approve.'
    end

    f.actions
  end

  permit_params do
    %i[need_review]
  end
end
