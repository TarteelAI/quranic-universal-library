# frozen_string_literal: true

ActiveAdmin.register Draft::Topic do
  menu parent: 'Drafts', label: 'Draft Topics'

  filter :resource_content_id, as: :select,
         collection: -> { ResourceContent.where(id: Topic.where.not(resource_content_id: nil).distinct.select(:resource_content_id)).order(:name).pluck(:name, :id) }
  filter :topic_id
  filter :need_review
  filter :imported
  filter :draft_name

  includes :user

  scope :all, default: true
  scope :pending_contributions

  action_item :review, only: :show do
    unless resource.imported?
      label = resource.need_review? ? 'Mark approved' : 'Mark for review'
      link_to label, review_cms_draft_topic_path(resource), method: :put
    end
  end

  action_item :import, only: :show do
    unless resource.imported?
      link_to 'Approve and update', import_cms_draft_topic_path(resource), method: :put, data: { confirm: 'Are you sure?' }
    end
  end

  member_action :review, method: 'put' do
    resource.update_columns(need_review: !resource.need_review?)

    redirect_to cms_draft_topic_path(resource),
                notice: resource.need_review? ? 'Marked for review' : 'Marked approved'
  end

  member_action :import, method: 'put' do
    topic = resource.import!

    redirect_to [:cms, topic], notice: 'Draft topic is approved and imported successfully'
  end

  index do
    id_column
    column :topic do |draft|
      link_to(draft.current_name, [:cms, draft.topic]) if draft.topic
    end
    column :changed do |draft|
      parts = draft.changed_fields.map(&:humanize)
      parts << "#{draft.added_verse_ids.size} ayahs added" if draft.added_verse_ids.any?
      parts << "#{draft.removed_verse_ids.size} ayahs removed" if draft.removed_verse_ids.any?
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
      row :topic do
        link_to(resource.current_name, [:cms, resource.topic]) if resource.topic
      end
      row :resource_content
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
      if resource.changed_fields.empty?
        para { span 'Name, Arabic name and description not changed', class: 'status_tag' }
      end

      resource.changed_fields.each do |field|
        h4 field.humanize
        div diff.call(resource["current_#{field}"], resource["draft_#{field}"]), dir: (field == 'arabic_name' ? 'rtl' : 'ltr')
      end

      if resource.added_verse_ids.any?
        h4 'Ayahs added'
        para resource.added_verses.pluck(:verse_key).join(', ')
      end

      if resource.removed_verse_ids.any?
        h4 'Ayahs removed'
        para resource.removed_verses.pluck(:verse_key).join(', ')
      end
    end

    others = Draft::Topic.where(topic_id: resource.topic_id).where.not(id: resource.id).order(id: :desc)
    if others.any?
      panel 'Other suggestions for this topic' do
        table_for others do
          column(:id) { |d| link_to d.id, cms_draft_topic_path(d) }
          column(:status) { |d| d.status }
          column :user
          column(:comment) { |d| d.comment.to_s.truncate(80) }
          column :created_at
        end
      end
    end
  end

  form do |f|
    f.inputs 'Topic detail' do
      f.input :draft_name
      f.input :draft_arabic_name
      f.input :draft_description, input_html: { rows: 4 }
      f.input :need_review, hint: 'Untick to approve.'
    end

    f.actions
  end

  permit_params do
    %i[draft_name draft_arabic_name draft_description need_review]
  end
end
