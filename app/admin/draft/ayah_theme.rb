# frozen_string_literal: true

ActiveAdmin.register Draft::AyahTheme do
  menu parent: 'Drafts', label: 'Draft Ayah Themes'

  filter :chapter_id, as: :select, collection: -> { (1..114).to_a }
  filter :ayah_theme_id
  filter :need_review
  filter :imported
  filter :draft_theme

  includes :user, :chapter, :resource_content

  scope :all, default: true
  scope :pending_contributions

  action_item :review, only: :show do
    unless resource.imported?
      label = resource.need_review? ? 'Mark approved' : 'Mark for review'
      link_to label, review_cms_draft_ayah_theme_path(resource), method: :put
    end
  end

  action_item :import, only: :show do
    unless resource.imported?
      link_to 'Approve and update', import_cms_draft_ayah_theme_path(resource), method: :put, data: { confirm: 'Are you sure?' }
    end
  end

  member_action :review, method: 'put' do
    resource.update_columns(need_review: !resource.need_review?)

    redirect_to cms_draft_ayah_theme_path(resource),
                notice: resource.need_review? ? 'Marked for review' : 'Marked approved'
  end

  member_action :import, method: 'put' do
    theme = resource.import!

    redirect_to [:cms, theme], notice: 'Draft ayah theme is approved and imported successfully'
  end

  index do
    id_column
    column :surah, sortable: :chapter_id do |draft|
      "#{draft.chapter_id}. #{draft.chapter&.name_simple}"
    end
    column :ayahs do |draft|
      draft.current_range_label
    end
    column :changed do |draft|
      parts = []
      parts << 'theme' if draft.theme_changed?
      parts << 'keywords' if draft.keywords_changed?
      parts << "ayahs #{draft.draft_range_label}" if draft.range_changed?
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
      row :ayah_theme do
        link_to("Theme ##{resource.ayah_theme_id}", [:cms, resource.ayah_theme]) if resource.ayah_theme
      end
      row :chapter
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
      h4 'Theme'
      resource.theme_changed? ? div(diff.call(resource.current_theme, resource.draft_theme)) : para(resource.draft_theme)

      h4 'Keywords'
      if resource.keywords_changed?
        div diff.call(Array(resource.current_keywords).join("\n"), Array(resource.draft_keywords).join("\n"))
      else
        para Array(resource.draft_keywords).join(', ')
      end

      h4 'Ayahs'
      if resource.range_changed?
        para "#{resource.current_range_label} → #{resource.draft_range_label}"
        theme = resource.ayah_theme.dup
        theme.id = resource.ayah_theme_id
        theme.set_range(resource.draft_verse_id_from, resource.draft_verse_id_to)
        overlapping = theme.overlapping_themes.to_a
        if overlapping.any?
          para "Approving shortens or removes: #{overlapping.map(&:range_label).join(', ')}"
        end
      else
        para resource.current_range_label
      end
    end

    others = Draft::AyahTheme.where(ayah_theme_id: resource.ayah_theme_id).where.not(id: resource.id).order(id: :desc)
    if others.any?
      panel 'Other suggestions for this theme' do
        table_for others do
          column(:id) { |d| link_to d.id, cms_draft_ayah_theme_path(d) }
          column(:status) { |d| d.status }
          column :user
          column(:comment) { |d| d.comment.to_s.truncate(80) }
          column :created_at
        end
      end
    end
  end

  form do |f|
    f.inputs 'Theme detail' do
      f.input :draft_theme
      f.input :need_review, hint: 'Untick to approve.'
    end

    f.actions
  end

  permit_params do
    %i[draft_theme need_review]
  end
end
