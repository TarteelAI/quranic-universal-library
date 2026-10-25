# frozen_string_literal: true

ActiveAdmin.register Draft::Transliteration do
  menu parent: 'Drafts', label: 'Draft Transliterations'

  filter :resource_content_id, as: :select,
         collection: -> { ResourceContent.transliteration.one_verse.order(:name).pluck(:name, :id) }
  filter :verse, as: :searchable_select,
         ajax: { resource: Verse }
  filter :text_matched
  filter :need_review
  filter :imported
  filter :draft_text
  filter :current_text

  includes :verse, :user

  scope :pending_contributions

  action_item :previous_page, only: :show do
    if (item = resource.previous_ayah_draft)
      link_to("Previous(#{item.verse.verse_key})", cms_draft_transliteration_path(item))
    end
  end

  action_item :review, only: :show do
    unless resource.imported?
      label = resource.need_review? ? 'Mark approved' : 'Mark for review'
      link_to label, review_cms_draft_transliteration_path(resource), method: :put
    end
  end

  action_item :import, only: :show do
    unless resource.imported?
      link_to 'Approve and update', import_cms_draft_transliteration_path(resource), method: :put, data: { confirm: 'Are you sure?' }
    end
  end

  action_item :next_page, only: :show do
    if (item = resource.next_ayah_draft)
      link_to "Next(#{item.verse.verse_key})", cms_draft_transliteration_path(item)
    end
  end

  member_action :review, method: 'put' do
    resource.update_columns(need_review: !resource.need_review?)

    redirect_to cms_draft_transliteration_path(resource),
                notice: resource.need_review? ? 'Marked for review' : 'Marked approved'
  end

  member_action :import, method: 'put' do
    transliteration = resource.import!

    redirect_to [:cms, transliteration], notice: 'Draft transliteration is approved and imported successfully'
  end

  index do
    id_column
    column :verse do |draft|
      link_to(draft.verse.verse_key, [:cms, draft.verse]) if draft.verse
    end
    column :resource do |draft|
      link_to(draft.resource_content.name, [:cms, draft.resource_content]) if draft.resource_content
    end
    column :text_matched
    column :need_review
    column :imported
    column :current_text, sortable: :current_text do |draft|
      safe_html draft.current_text.to_s.truncate(80)
    end
    column :draft_text, sortable: :draft_text do |draft|
      safe_html draft.draft_text.to_s.truncate(80)
    end

    column :comment do |draft|
      draft.comment.to_s.truncate(60)
    end

    actions
  end

  show do
    language_name = resource.resource_content&.language_name.to_s.downcase

    attributes_table do
      row :id
      row :resource_content
      row :verse do
        div link_to(resource.verse.verse_key, [:cms, resource.verse])
        div resource.verse.text_qpc_hafs, class: 'qpc-hafs'
      end
      row :text do
        render 'admin/draft_compare', current: resource.current_text, draft: resource.draft_text,
               text_class: language_name, height_class: 'max-h-[80vh]',
               empty_message: 'New transliteration, this ayah has none yet'
      end
      row :diff do
        Diffy::Diff.new(resource.current_text.to_s, resource.draft_text.to_s, include_plus_and_minus_in_html: true).to_s(:html).html_safe
      end
      row :text_matched
      row :need_review
      row :imported
      row :user
      row :comment
      row :meta_data do
        if resource.meta_data.present?
          pre code(JSON.pretty_generate(resource.meta_data))
        end
      end
      row :created_at
      row :updated_at
    end
  end

  form do |f|
    f.inputs 'Transliteration detail' do
      f.input :verse, as: :searchable_select, ajax: { resource: Verse }
      f.input :draft_text
      f.input :need_review, hint: 'Untick to approve.'
    end

    f.actions
  end

  sidebar 'Transliterations', only: :index do
    stats = Draft::Transliteration.resource_stats
    selected = params.dig(:q, :resource_content_id_eq).to_i

    render 'admin/draft/transliteration_resources',
           stats: stats.sort_by { |t| t[:resource]&.id == selected ? 0 : 1 },
           selected: selected,
           filter_path: '/cms/draft_transliterations'
  end

  permit_params do
    %i[verse_id draft_text need_review]
  end
end
