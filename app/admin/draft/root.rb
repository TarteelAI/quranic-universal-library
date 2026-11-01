# frozen_string_literal: true

ActiveAdmin.register Draft::Root do
  menu parent: 'Drafts', label: 'Draft Roots'

  filter :root_id
  filter :need_review
  filter :imported
  filter :draft_arabic_trilateral

  includes :user

  scope :all, default: true
  scope :pending_contributions

  action_item :review, only: :show do
    unless resource.imported?
      label = resource.need_review? ? 'Mark approved' : 'Mark for review'
      link_to label, review_cms_draft_root_path(resource), method: :put
    end
  end

  action_item :import, only: :show do
    unless resource.imported?
      link_to 'Approve and update', import_cms_draft_root_path(resource), method: :put, data: { confirm: 'Are you sure?' }
    end
  end

  member_action :review, method: 'put' do
    resource.update_columns(need_review: !resource.need_review?)

    redirect_to cms_draft_root_path(resource),
                notice: resource.need_review? ? 'Marked for review' : 'Marked approved'
  end

  member_action :import, method: 'put' do
    resource.import!

    # The CMS has no page for one root, cms_root is the dashboard
    redirect_to cms_draft_root_path(resource), notice: 'Draft root is approved and imported successfully'
  end

  index do
    id_column
    column :root do |draft|
      link_to(draft.current_arabic_trilateral, arabic_root_path(draft.root_id))
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
      row :root do
        link_to(resource.current_arabic_trilateral, arabic_root_path(resource.root_id))
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
        from = resource["current_#{field}"]
        to = resource["draft_#{field}"]
        from, to = Array(from).join("\n"), Array(to).join("\n") if field.end_with?('meanings')

        h4 field.humanize
        div diff.call(from, to), dir: (%w[arabic_trilateral text_uthmani ur_meanings].include?(field) ? 'rtl' : 'ltr')
      end
    end

    others = Draft::Root.where(root_id: resource.root_id).where.not(id: resource.id).order(id: :desc)
    if others.any?
      panel 'Other suggestions for this root' do
        table_for others do
          column(:id) { |d| link_to d.id, cms_draft_root_path(d) }
          column(:status) { |d| d.status }
          column :user
          column(:comment) { |d| d.comment.to_s.truncate(80) }
          column :created_at
        end
      end
    end
  end

  form do |f|
    f.inputs 'Root detail' do
      f.input :draft_arabic_trilateral
      f.input :draft_english_trilateral
      f.input :draft_text_uthmani
      f.input :need_review, hint: 'Untick to approve.'
    end

    f.actions
  end

  permit_params do
    %i[draft_arabic_trilateral draft_english_trilateral draft_text_uthmani need_review]
  end
end
