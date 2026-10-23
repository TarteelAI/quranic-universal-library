# frozen_string_literal: true

ActiveAdmin.register Draft::WordTransliteration do
  menu parent: 'Drafts', label: 'Draft Word Transliterations'

  filter :resource_content_id, as: :select,
         collection: -> { ResourceContent.transliteration.one_word.order(:name).pluck(:name, :id) }
  filter :verse, as: :searchable_select,
         ajax: { resource: Verse }
  filter :location
  filter :text_matched
  filter :need_review
  filter :imported
  filter :draft_text
  filter :current_text

  includes :word

  action_item :previous_word, only: :show do
    if (item = resource.previous_word_draft)
      link_to("Previous(#{item.location})", cms_draft_word_transliteration_path(item))
    end
  end

  action_item :review, only: :show do
    unless resource.imported?
      label = resource.need_review? ? 'Mark approved' : 'Mark for review'
      link_to label, review_cms_draft_word_transliteration_path(resource), method: :put
    end
  end

  action_item :import, only: :show do
    unless resource.imported?
      link_to 'Approve and update', import_cms_draft_word_transliteration_path(resource), method: :put, data: { confirm: 'Are you sure?' }
    end
  end

  action_item :next_word, only: :show do
    if (item = resource.next_word_draft)
      link_to "Next(#{item.location})", cms_draft_word_transliteration_path(item)
    end
  end

  member_action :review, method: 'put' do
    resource.update_columns(need_review: !resource.need_review?)

    redirect_to cms_draft_word_transliteration_path(resource),
                notice: resource.need_review? ? 'Marked for review' : 'Marked approved'
  end

  member_action :import, method: 'put' do
    word_transliteration = resource.import!

    redirect_to [:cms, word_transliteration], notice: 'Draft word transliteration is approved and imported successfully'
  end

  index do
    id_column
    column :location, sortable: :location do |draft|
      link_to(draft.location, [:cms, draft.word]) if draft.word
    end
    column :word do |draft|
      span draft.word&.text_qpc_hafs, class: 'qpc-hafs'
    end
    column :resource_content_id
    column :text_matched
    column :need_review
    column :imported
    column :current_text
    column :draft_text

    column :comment do |draft|
      draft.comment.to_s.truncate(60)
    end

    actions
  end

  show do
    attributes_table do
      row :id
      row :resource_content
      row :verse do
        link_to(resource.verse.verse_key, [:cms, resource.verse]) if resource.verse
      end
      row :word do
        div link_to(resource.location, [:cms, resource.word])
        div resource.word.text_qpc_hafs, class: 'qpc-hafs'
      end
      row :current_text do
        if resource.current_text.present?
          resource.current_text
        else
          span 'New transliteration, this word has none yet', class: 'status_tag no'
        end
      end
      row :draft_text
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
    f.inputs 'Word transliteration detail' do
      f.input :word, as: :searchable_select, ajax: { resource: Word }
      f.input :draft_text
      f.input :need_review, hint: 'Untick to approve'
    end

    f.actions
  end

  sidebar 'Word transliterations', only: :index do
    stats = Draft::WordTransliteration.resource_stats
    selected = params.dig(:q, :resource_content_id_eq).to_i

    render 'admin/draft/transliteration_resources',
           stats: stats.sort_by { |t| t[:resource]&.id == selected ? 0 : 1 },
           selected: selected,
           filter_path: '/cms/draft_word_transliterations'
  end

  permit_params do
    %i[word_id draft_text need_review]
  end
end
