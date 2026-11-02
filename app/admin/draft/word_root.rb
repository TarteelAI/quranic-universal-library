# frozen_string_literal: true

ActiveAdmin.register Draft::WordRoot do
  menu parent: 'Drafts', label: 'Draft Word Roots'

  # One suggestion can change many words, approve them together
  config.batch_actions = true

  filter :location
  filter :verse_id
  filter :current_root_id
  filter :current_lemma_id
  filter :need_review
  filter :imported

  includes :user

  scope :all, default: true
  scope :pending_contributions

  batch_action :approve_and_update, confirm: 'Approve and update the selected words?' do |ids|
    drafts = Draft::WordRoot.where(id: ids, imported: false)
    drafts.each(&:import!)

    redirect_to collection_path(scope: 'pending_contributions'), notice: "#{drafts.size} words updated"
  end

  batch_action :destroy, false

  action_item :review, only: :show do
    unless resource.imported?
      label = resource.need_review? ? 'Mark approved' : 'Mark for review'
      link_to label, review_cms_draft_word_root_path(resource), method: :put
    end
  end

  action_item :import, only: :show do
    unless resource.imported?
      link_to 'Approve and update', import_cms_draft_word_root_path(resource), method: :put, data: { confirm: 'Are you sure?' }
    end
  end

  member_action :review, method: 'put' do
    resource.update_columns(need_review: !resource.need_review?)

    redirect_to cms_draft_word_root_path(resource),
                notice: resource.need_review? ? 'Marked for review' : 'Marked approved'
  end

  member_action :import, method: 'put' do
    resource.import!

    redirect_to cms_draft_word_root_path(resource), notice: 'Draft is approved and the word is updated'
  end

  index do
    selectable_column
    id_column
    column :word do |draft|
      link_to draft.location, word_root_path(draft.verse_id)
    end
    column :now do |draft|
      draft.current_text
    end
    column :suggested do |draft|
      draft.draft_text
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
    attributes_table title: 'Suggestion' do
      row :word do
        link_to "#{resource.location} #{resource.word&.text_qpc_hafs}", word_root_path(resource.verse_id)
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

    panel 'Changes' do
      table_for resource.changed_links do
        column(:link) { |link| link.humanize }
        column(:now) { |link| Draft::WordRoot.label(resource.linked(link, 'current')) || 'none' }
        column(:suggested) { |link| Draft::WordRoot.label(resource.linked(link, 'draft')) || 'none' }
      end
    end

    others = Draft::WordRoot.where(word_id: resource.word_id).where.not(id: resource.id).order(id: :desc)
    if others.any?
      panel 'Other suggestions for this word' do
        table_for others do
          column(:id) { |d| link_to d.id, cms_draft_word_root_path(d) }
          column(:status) { |d| d.status }
          column(:suggested) { |d| d.draft_text }
          column :user
          column :created_at
        end
      end
    end
  end

  form do |f|
    f.inputs 'Review' do
      f.input :need_review, hint: 'Untick to approve.'
    end

    f.actions
  end

  permit_params do
    %i[need_review]
  end
end
