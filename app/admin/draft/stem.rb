# frozen_string_literal: true

ActiveAdmin.register Draft::Stem do
  menu parent: 'Drafts', label: 'Draft Stems'

  filter :stem_id
  filter :need_review
  filter :imported
  filter :draft_text_clean

  includes :user

  scope :all, default: true
  scope :pending_contributions

  action_item :review, only: :show do
    unless resource.imported?
      label = resource.need_review? ? 'Mark approved' : 'Mark for review'
      link_to label, review_cms_draft_stem_path(resource), method: :put
    end
  end

  action_item :import, only: :show do
    unless resource.imported?
      link_to 'Approve and update', import_cms_draft_stem_path(resource), method: :put, data: { confirm: 'Are you sure?' }
    end
  end

  member_action :review, method: 'put' do
    resource.update_columns(need_review: !resource.need_review?)

    redirect_to cms_draft_stem_path(resource),
                notice: resource.need_review? ? 'Marked for review' : 'Marked approved'
  end

  member_action :import, method: 'put' do
    stem = resource.import!

    redirect_to [:cms, stem], notice: 'Draft stem is approved and imported successfully'
  end

  index do
    id_column
    column :stem do |draft|
      link_to(draft.current_text_madani, stem_path(draft.stem_id))
    end
    column :changed do |draft|
      parts = draft.changed_fields.map(&:humanize)
      parts.any? ? parts.join(', ') : span('no change', class: 'status_tag')
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
    diff = lambda do |from, to|
      Diffy::Diff.new("#{from}\n", "#{to}\n", include_plus_and_minus_in_html: true).to_s(:html).html_safe
    end

    attributes_table title: 'Suggestion' do
      row :stem do
        link_to(resource.current_text_madani, stem_path(resource.stem_id))
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
      resource.changed_fields.each do |field|
        h4 field.humanize
        div diff.call(resource["current_#{field}"], resource["draft_#{field}"]), dir: 'rtl'
      end
    end

    others = Draft::Stem.where(stem_id: resource.stem_id).where.not(id: resource.id).order(id: :desc)
    if others.any?
      panel 'Other suggestions for this stem' do
        table_for others do
          column(:id) { |d| link_to d.id, cms_draft_stem_path(d) }
          column(:status) { |d| d.status }
          column :user
          column(:comment) { |d| d.comment.to_s.truncate(80) }
          column :created_at
        end
      end
    end
  end

  form do |f|
    f.inputs 'Stem detail' do
      f.input :draft_text_madani
      f.input :draft_text_clean
      f.input :need_review, hint: 'Untick to approve.'
    end

    f.actions
  end

  permit_params do
    %i[draft_text_madani draft_text_clean need_review]
  end
end
