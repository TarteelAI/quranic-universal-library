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
    column :chapter do |draft|
      link_to(draft.chapter.name_simple, [:cms, draft.chapter]) if draft.chapter
    end
    column :resource do |draft|
      link_to(draft.resource_content.name, [:cms, draft.resource_content]) if draft.resource_content
    end
    column :text_matched
    column :need_review
    column :imported
    column :user
    column :created_at

    actions
  end

  show do
    language_name = resource.resource_content&.language_name.to_s.downcase
    diff = lambda do |from, to|
      Diffy::Diff.new(from.to_s, to.to_s, include_plus_and_minus_in_html: true).to_s(:html).html_safe
    end

    attributes_table do
      row :id
      row :resource_content
      row :chapter
      row :current_short_text, class: language_name
      row :draft_short_text, class: language_name
      row 'Short text diff' do
        diff.call(resource.current_short_text, resource.draft_short_text)
      end
      row :current_text, class: language_name do
        if resource.current_text.present?
          safe_html resource.current_text
        else
          span 'New surah info, this surah has none yet', class: 'status_tag no'
        end
      end
      row :draft_text, class: language_name do
        safe_html resource.draft_text
      end
      row 'Text diff' do
        diff.call(resource.current_text, resource.draft_text)
      end
      row :text_matched
      row :need_review
      row :imported
      row :user
      row :created_at
      row :updated_at
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
