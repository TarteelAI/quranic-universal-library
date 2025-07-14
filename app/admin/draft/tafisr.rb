# frozen_string_literal: true

ActiveAdmin.register Draft::Tafsir do
  menu parent: 'Drafts'

  filter :resource_content,
         as: :searchable_select,
         ajax: { resource: ResourceContent }

  filter :verse,
         as: :searchable_select,
         ajax: { resource: Verse }

  filter :group_tafsir,
         as: :searchable_select,
         ajax: { resource: Verse }

  filter :verse_key, as: :string, label: "Ayah (Verse Key)"

  filter :text_matched
  filter :need_review
  filter :reviewed
  filter :imported
  filter :group_verses_count

  includes :resource_content

  action_item :import, only: :show do
    link_to import_cms_draft_tafsir_path(resource), method: :put, data: { confirm: 'Are you sure?' } do
      'Approve and update'
    end if !resource.imported? && can?(:manage, :draft_content)
  end

  action_item :clone_item, only: :show do
    if can?(:manage, :draft_content)
      link_to "Clone(#{resource.verse_key})", clone_item_cms_draft_tafsir_path(resource), method: :put, data: { confirm: 'Are you sure to clone?' }
    end
  end

  action_item :reprocess, only: :show do
    if can?(:manage, :draft_content)
      link_to "Sanitize text", reprocess_cms_draft_tafsir_path(resource), method: :put, data: { confirm: 'Are you sure?' }
    end
  end

  action_item :previous, only: :show do
    if item = resource.previous_ayah_tafsir
      link_to("Previous(#{item.start_verse.verse_key})", "/cms/draft_tafsirs/#{item.id}", class: 'btn') if item
    end
  end

  action_item :next, only: :show do
    if item = resource.next_ayah_tafsir
      link_to "Next(#{item.start_verse.verse_key})", "/cms/draft_tafsirs/#{item.id}", class: 'btn'
    end
  end

  member_action :import, method: 'put' do
    tafsir = resource.import!

    redirect_to [:cms, tafsir], notice: 'Draft Tafsir is approved and imported successfully'
  end

  member_action :clone_item, method: 'put' do
    tafsir = resource.clone_tafsir

    redirect_to [:cms, tafsir], notice: 'Cloned successfully'
  end

  member_action :reprocess, method: 'put' do
    resource.reprocess_text!
    redirect_to [:cms, resource], notice: 'Text formatting is reprocessed'
  end

  index do
    id_column
    column :text_matched
    column :need_review
    column :reviewed
    column :resource_content
    column :from, sortable: :start_verse_id do |resource|
      span resource.group_verse_key_from, class: "status_tag #{'yes' if resource.verse_key == resource.group_verse_key_from}"
    end
    column :to, sortable: :end_verse_id do |resource|
      resource.group_verse_key_to
    end

    column :verse, sortable: :verse_id do |resource|
      link_to resource.verse.verse_key, [:cms, resource.verse] if resource.verse
    end
    column :imported
    column :text do |resource|
      resource.draft_text.to_s.first(50)
    end
    column :grp_size, sortable: :group_verses_count do |resource|
      resource.group_verses_count
    end

    column :created_at
    column :updated_at
  end

  form do |f|
    f.inputs 'Tafsir detail' do
      f.input :draft_text, input_html: { data: { controller: 'tinymce' } }
      f.input :need_review
      f.input :reviewed

      f.input :start_verse_id,
              as: :searchable_select,
              ajax: { resource: Verse }

      f.input :end_verse_id,
              as: :searchable_select,
              ajax: { resource: Verse }

      f.input :group_tafsir_id,
              as: :searchable_select,
              ajax: { resource: Verse }

      f.input :draft_text, input_html: { data: { controller: 'tinymce' } }
    end

    f.actions
  end

  show do
    language_name = resource.resource_content.language_name
    tafsir = resource.tafsir || resource.original_tafsir

    attributes_table do
      row :id
      row :resource_content
      row :user

      row :tafsir do
        if tafsir
          link_to tafsir.id, [:cms, tafsir]
        end
      end

      row :group_verse_key_from
      row :group_verse_key_to

      row :group_tafsir do |resource|
        if resource.group_tafsir
          div do
            span link_to(resource.group_tafsir.verse_key, [:cms, resource.group_tafsir]), class: 'mr-4'
            span(link_to('View group tafsir', [:cms, resource.main_group_tafsir])) if resource.main_group_tafsir
          end
        end
      end

      row :group_verses_count

      row :text_matched
      row :imported
      row :need_review
      row :reviewed
      row :comments

      row :created_at
      row :updated_at

      row :verse do
        div do
          link_to(resource.verse.verse_key, [:cms, resource.verse])

          div class: 'arabic qpc-hafs' do
            resource.verse.text_qpc_hafs
          end
        end
      end

      row :text do
        render "admin/tafisr_compare", language_name: language_name, tafsir: tafsir
      end

      row :diff do
        div Diffy::Diff.new(resource.current_text.to_s, resource.draft_text.to_s).to_s(:html).html_safe
      end

      row :quran_enc_link do
        if source_path = resource.source_link
          div do
            link_to('View Source', source_path,
                    target: '_blank',
                    rel: 'noopener')
          end
        end
      end

      row :meta_data do
        if resource.meta_data.present?
          div do
            pre do
              code do
                JSON.pretty_generate(resource.meta_data)
              end
            end
          end
        end
      end
    end
  end

  sidebar 'Draft tafsirs', only: :index do
    tafsirs = Draft::Tafsir.all_tafsirs
    selected = params.dig(:q, :resource_content_id_eq).to_i

    tafsirs = tafsirs.sort_by { |t| t[:resource] && t[:resource].id == selected ? 0 : 1 }
    imported = tafsirs.select do |t|
      t[:total_count] == t[:imported_count]
    end

    div "Total Resources: #{tafsirs.size}"
    div "Imported: #{imported.size}"

    div class: 'd-flex w-100 flex-column sidebar-item' do
      tafsirs.each do |t|
        resource_content = t[:resource]
        next if resource_content.nil?

        is_fully_imported = t[:total_count] > 0 && t[:total_count] == t[:imported_count]

        div class: "w-100 p-2 border-bottom mb-3 #{'selected' if selected == resource_content.id}" do
          div class: 'flex-between' do
            span link_to(resource_content.id, [:cms, resource_content], target: '_blank')
            span('Imported', class: 'status_tag yes ms-2') if is_fully_imported
          end

          div "#{resource_content.name} (#{resource_content.language_name})"
          div "Synced: #{resource_content.meta_value('synced-at')} | Updated: #{resource_content.updated_at}"

          # Display stats per resource
          div class: 'small text-muted' do
            span "Total: #{t[:total_count]}, "
            span "Matched: #{t[:matched_count]}, "
            span "Not Matched: #{t[:not_matched_count]}, "
            span "Imported: #{t[:imported_count]}, "
            span "Not Imported: #{t[:not_imported_count]}, "
            span "Need Review: #{t[:need_review_count]}"
          end

          div class: 'd-flex my-2 flex-between gap-2' do
            span(link_to 'Filter', "/cms/draft_tafsirs?q%5Bresource_content_id_eq%5D=#{resource_content.id}", class: 'btn btn-sm btn-info text-white')

            issue_count = AdminTodo.where(resource_content_id: resource_content.id).count

            if can?(:manage, :draft_content)
              span(link_to 'Sync', import_draft_cms_resource_content_path(resource_content), method: 'put', class: 'btn btn-sm btn-success text-white', data: { confirm: 'Are you sure to re-sync this tafsir from the source?' })

              if issue_count.positive?
                span(link_to "Issues #{issue_count}", "/cms/admin_todos?q%5Bresource_content_id_eq%5D=#{resource_content.id}&order=id_desc", class: 'btn btn-sm btn-warning text-white')
              end

              span(link_to 'Validate', validate_draft_cms_resource_content_path(resource_content), class: 'btn btn-sm btn-success text-white', data: { controller: 'ajax-modal', url: validate_draft_cms_resource_content_path(resource_content) })
              span(link_to 'Compare grouping', compare_ayah_grouping_cms_resource_content_path(resource_content), class: 'btn btn-sm btn-success text-white', data: { controller: 'ajax-modal', url: compare_ayah_grouping_cms_resource_content_path(resource_content), css_class: 'modal-lg' })

              span(link_to 'Approve', import_draft_cms_resource_content_path(resource_content, approved: true), method: 'put', class: 'btn btn-sm btn-warning text-white', data: { confirm: 'Are you sure to import this tafsir?' })
              span(link_to 'Delete', import_draft_cms_resource_content_path(resource_content, remove_draft: true), method: 'put', class: 'btn btn-sm btn-danger text-white', data: { confirm: 'Are you sure to remove draft tafsir?' })
            end
          end
        end
      end
    end
  end

  controller do
    def update
      super
      resource.update_ayah_grouping
    end
  end

  permit_params do
    %i[
      draft_text
      start_verse_id
      end_verse_id
      group_tafsir_id
    ]
  end
end
