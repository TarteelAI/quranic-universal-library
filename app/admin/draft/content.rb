# frozen_string_literal: true

ActiveAdmin.register Draft::Content do
  menu parent: 'Drafts'

  filter :location
  filter :chapter, as: :searchable_select,
         ajax: { resource: Chapter }
  filter :verse, as: :searchable_select,
         ajax: { resource: Verse }
  filter :word, as: :searchable_select,
         ajax: { resource: Word }
  filter :resource_content, as: :searchable_select,
         ajax: { resource: ResourceContent }
  filter :text_matched
  filter :need_review
  filter :imported
  filter :draft_text
  filter :text

  includes :resource_content

  action_item :approve, only: :show do
    if !resource.imported? && can?(:manage, :draft_content)
      link_to approve_cms_draft_content_path(resource), method: :put,
              data: { confirm: 'Are you sure?' } do
        'Approve and update'
      end
    end
  end

  member_action :approve, method: :put do
    resource.import!
    redirect_to [:cms, resource], notice: 'Draft content has been approved and imported'
  end

  index do
    id_column
    column :location
    column :text_matched
    column :need_review
    column :imported
    column :resource do |resource|
      link_to resource.resource_content.name, [:cms, resource.resource_content]
    end
    column :draft_text, sortable: :draft_text do |resource|
      resource.draft_text.to_s.first(50)
    end
    column :current_text, sortable: :current_text do |resource|
      resource.current_text.to_s.first(50)
    end
    actions
  end

  sidebar 'Draft resources', only: :index do
    drafts = Draft::Content.draft_resources
    selected = params.dig(:q, :resource_content_id_eq).to_i
    drafts = drafts.sort_by { |t| t[:resource]&.id == selected ? 0 : 1 }
    imported = drafts.select { |t| t[:total_count] == t[:imported_count] }

    div "Total Resources: #{drafts.size}"
    div "Imported: #{imported.size}"

    div class: 'd-flex w-100 flex-column sidebar-item' do
      drafts.each do |t|
        resource_content = t[:resource]
        next unless resource_content

        is_fully_imported = t[:total_count].positive? && t[:total_count] == t[:imported_count]

        div class: "w-100 p-2 border-bottom mb-3 #{'selected' if selected == resource_content.id}" do
          div class: 'flex-between' do
            span link_to(resource_content.id, [:cms, resource_content], target: '_blank')
            span('Imported', class: 'status_tag yes ms-2') if is_fully_imported
          end

          div "#{resource_content.name} (#{resource_content.language_name})"
          div "Synced: #{resource_content.meta_value('synced-at')} | Updated: #{resource_content.updated_at}"

          div class: 'small text-muted' do
            span "Total: #{t[:total_count]}, "
            span "Matched: #{t[:matched_count]}, "
            span "Not Matched: #{t[:not_matched_count]}, "
            span "Imported: #{t[:imported_count]}, "
            span "Not Imported: #{t[:not_imported_count]}, "
            span "Need Review: #{t[:need_review_count]}"
          end

          div class: 'd-flex my-2 flex-between gap-2' do
            span link_to('Filter', "/cms/draft_contents?q%5Bresource_content_id_eq%5D=#{resource_content.id}", class: 'btn btn-sm btn-info text-white')
            issue_count = AdminTodo.where(resource_content_id: resource_content.id).count
            if can?(:manage, :draft_content)
              if issue_count.positive?
                span link_to("Issues #{issue_count}", "/cms/admin_todos?q%5Bresource_content_id_eq%5D=#{resource_content.id}&order=id_desc", class: 'btn btn-sm btn-warning text-white')
              end
              span link_to('Approve', import_draft_content_cms_resource_content_path(resource_content, approved: true),
                           method: :put,
                           class: 'btn btn-sm btn-warning text-white',
                           data: { confirm: 'Are you sure to import this resource?' })
            end
          end
        end
      end
    end
  end

  form do |f|
    f.inputs 'Resource detail' do
      f.input :draft_text
    end
    f.actions
  end

  show do
    attributes_table do
      row :id
      row :location
      row :chapter
      row :verse
      row :word
      row :resource_content
      row :current_text do
        resource.current_text.to_s.html_safe
      end
      row :draft_text do
        resource.draft_text.to_s.html_safe
      end
      row :text_matched
      row :imported
      row :diff do
        Diffy::Diff.new(resource.current_text.to_s, resource.draft_text.to_s,
                        include_plus_and_minus_in_html: true)
                   .to_s(:html).html_safe
      end
      row :created_at
      row :updated_at
    end
  end

  permit_params do
    [:draft_text]
  end
end
