# frozen_string_literal: true

ActiveAdmin.register Draft::SurahInfo do
  menu parent: 'Drafts', label: 'Draft Surah Info'

  filter :resource_content_id, as: :select,
         collection: -> { ResourceContent.chapter_info.order(:name).pluck(:name, :id) }
  filter :chapter_id, as: :select, collection: -> { (1..114).to_a }
  filter :text_matched
  filter :need_review
  filter :imported
  filter :draft_text
  filter :current_text

  includes :chapter, :user, :resource_content

  action_item :previous_page, only: :show do
    if (item = resource.previous_surah_draft)
      link_to("Previous(#{item.chapter_id})", cms_draft_surah_info_path(item))
    end
  end

  action_item :review, only: :show do
    unless resource.imported?
      label = resource.need_review? ? 'Mark approved' : 'Mark for review'
      link_to label, review_cms_draft_surah_info_path(resource), method: :put
    end
  end

  action_item :import, only: :show do
    unless resource.imported?
      link_to 'Approve and update', import_cms_draft_surah_info_path(resource), method: :put, data: { confirm: 'Are you sure?' }
    end
  end

  action_item :next_page, only: :show do
    if (item = resource.next_surah_draft)
      link_to "Next(#{item.chapter_id})", cms_draft_surah_info_path(item)
    end
  end

  member_action :review, method: 'put' do
    resource.update_columns(need_review: !resource.need_review?)

    redirect_to cms_draft_surah_info_path(resource),
                notice: resource.need_review? ? 'Marked for review' : 'Marked approved'
  end

  member_action :import, method: 'put' do
    info = resource.import!

    redirect_to [:cms, info], notice: 'Draft surah info is approved and imported successfully'
  end

  index do
    id_column
    column :chapter, sortable: :chapter_id do |draft|
      link_to("#{draft.chapter_id}. #{draft.chapter.name_simple}", [:cms, draft.chapter]) if draft.chapter
    end
    column :resource do |draft|
      link_to(draft.resource_content.name, [:cms, draft.resource_content]) if draft.resource_content
    end
    column :changed do |draft|
      parts = []
      parts << 'short text' if draft.short_text_edited?
      parts << 'text' if draft.text_edited?
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
    language = resource.resource_content&.language
    dir = language&.direction == 'rtl' ? 'rtl' : 'ltr'
    diff = lambda do |from, to|
      Diffy::Diff.new("#{from}\n", "#{to}\n", include_plus_and_minus_in_html: true).to_s(:html).html_safe
    end

    attributes_table title: 'Suggestion' do
      row :chapter do
        link_to("#{resource.chapter_id}. #{resource.chapter.name_simple}", [:cms, resource.chapter])
      end
      row :resource_content
      row :user
      row :comment do
        resource.comment.presence || span('No comment', class: 'status_tag')
      end
      row :status do
        status_tag resource.status, class: resource.need_review? && !resource.imported? ? 'no' : 'yes'
      end
      row :original do
        info = resource.original_surah_info
        info ? link_to("Surah info ##{info.id}", [:cms, info]) : span('New, this surah has no info yet', class: 'status_tag no')
      end
      row :created_at
    end

    panel 'Short text' do
      if resource.short_text_edited?
        div diff.call(resource.current_short_text, resource.draft_short_text), dir: dir
      else
        para { span 'Not changed', class: 'status_tag' }
        div resource.draft_short_text, class: 'surah-info-text', dir: dir
      end
    end

    panel 'Text changes' do
      current_lines = Draft::SurahInfo.text_lines(resource.current_text)
      draft_lines = Draft::SurahInfo.text_lines(resource.draft_text)

      if current_lines != draft_lines
        para 'Changed paragraphs, as plain text. Removed lines are red, added lines green.'
        div diff.call(current_lines, draft_lines), dir: dir
      elsif resource.text_edited?
        para 'Only the formatting changed (tags or styles), the words are the same. Compare the two texts below.'
      else
        para { span 'Not changed', class: 'status_tag' }
      end
    end

    panel 'Current and suggested text' do
      render 'admin/draft_compare', current: resource.current_text, draft: resource.draft_text,
             text_class: 'surah-info-text', dir: dir, empty_message: 'New, this surah has no info yet'
    end

    others = Draft::SurahInfo.where(resource_content_id: resource.resource_content_id, chapter_id: resource.chapter_id).where.not(id: resource.id).order(id: :desc)
    if others.any?
      panel 'Other suggestions for this surah' do
        table_for others do
          column(:id) { |d| link_to d.id, cms_draft_surah_info_path(d) }
          column(:status) { |d| d.status }
          column :user
          column(:comment) { |d| d.comment.to_s.truncate(80) }
          column :created_at
        end
      end
    end
  end

  form do |f|
    f.inputs 'Surah info detail' do
      f.input :chapter_id, as: :select, collection: (1..114).to_a
      f.input :draft_short_text, input_html: { rows: 3 }
      f.input :draft_text, input_html: { data: { controller: 'tinymce' } }
      f.input :need_review, hint: 'Untick to approve.'
    end

    f.actions
  end

  sidebar 'Surah info', only: :index do
    stats = Draft::SurahInfo.resource_stats
    selected = params.dig(:q, :resource_content_id_eq).to_i

    render 'admin/draft/transliteration_resources',
           stats: stats.sort_by { |t| t[:resource]&.id == selected ? 0 : 1 },
           selected: selected,
           filter_path: '/cms/draft_surah_infos'
  end

  permit_params do
    %i[chapter_id draft_short_text draft_text need_review]
  end
end
