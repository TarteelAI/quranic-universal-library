# frozen_string_literal: true

ActiveAdmin.register Draft::Translation do
  menu parent: 'Drafts'

  filter :resource_content, as: :searchable_select,
         ajax: { resource: ResourceContent }
  filter :verse, as: :searchable_select,
         ajax: { resource: Verse }
  filter :text_matched
  filter :need_review
  filter :imported
  filter :draft_text
  filter :footnotes_count
  filter :current_footnotes_count

  includes :verse,
           :resource_content

  scope :with_footnotes, group: :footnotes
  scope :with_mismatch_footnote, group: :footnotes

  action_item :previous_page, only: :show do
    if item = resource.previous_ayah_translation
      link_to("Previous(#{item.verse.verse_key})", "/cms/draft_translations/#{item.id}", class: 'btn') if item
    end
  end

  action_item :import, only: :show do
    link_to import_cms_draft_translation_path(resource), method: :put, data: { confirm: 'Are you sure?' } do
      'Approve and update'
    end if !resource.imported?
  end

  action_item :next_page, only: :show do
    if item = resource.next_ayah_translation
      link_to "Next(#{item.verse.verse_key})", "/cms/draft_translations/#{item.id}", class: 'btn'
    end
  end

  member_action :import, method: 'put' do
    translation = resource.import!

    redirect_to [:cms, translation], notice: 'Draft translation is approved and imported successfully'
  end

  index do
    id_column
    column :text_matched
    column :need_review
    column :verse_id do |resource|
      link_to(resource.verse.verse_key, [:cms, resource.verse])
    end
    column :imported
    column :resource do |resource|
      link_to(resource.resource_content.name, [:cms, resource.resource_content]) if resource.resource_content
    end
    column :footnotes_count
    column :current_footnotes_count
    column :draft_text, sortable: :draft_text do |resource|
      resource.draft_text.to_s.first(50)
    end

    column :current_text, sortable: :current_text do |resource|
      resource.current_text.to_s.first(50)
    end

    actions
  end

  form do |f|
    f.inputs 'Translation detail' do
      f.input :draft_text
    end

    f.actions
  end

  show do
    language_name = resource.resource_content.language_name

    attributes_table do
      row :id
      row :resource_content
      row :translation
      row :verse do |resource|
        div do
          link_to resource.verse.verse_key, cms_verse_path(resource.verse)
        end
        div class: 'qpc-hafs' do
          resource.verse.text_qpc_hafs
        end
      end
      row :current_text, class: language_name, 'data-controller': 'translation' do
        div do
          span safe_html(resource.current_text)
        end
      end

      row :draft_text, class: language_name, 'data-controller': 'translation', draft: true do
        safe_html resource.draft_text
      end

      row :text_matched
      row :imported
      row :footnotes_count

      row :diff do
        div do
          div Diffy::Diff.new(resource.current_text.to_s, resource.draft_text.to_s, include_plus_and_minus_in_html: true).to_s(:html).html_safe
        end
      end

      row :verse do
        link_to(resource.verse.verse_key, [:cms, resource.verse])
      end

      row :quran_enc_link do
        resource_content = resource.resource_content
        verse = resource.verse
        div do
          link_to('View on QuranEnc',
                  "https://quranenc.com/en/browse/#{resource_content.quran_enc_key}/#{verse.verse_key.sub(':', '/')}",
                  target: '_blank',
                  rel: 'noopener')
        end
      end
      row :created_at
      row :updated_at

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

    panel 'Footnotes' do
      table border: 1 do
        thead do
          th 'Id'
          th 'Draft Text'
          th 'Current Text'
          th 'Matched?'
        end

        tbody do
          resource.foot_notes.each_with_index do |foot_note, index|
            tr do
              td link_to(foot_note.id, [:cms, foot_note])

              td class: language_name do
                safe_html foot_note.draft_text
              end

              td class: language_name do
                safe_html foot_note.current_text
              end

              td foot_note.text_matched? ? 'Yes' : 'No'
            end
          end
        end
      end
    end
  end

  sidebar 'Draft Translations', only: :index do
    translations = Draft::Translation.all_translations
    selected = params.dig(:q, :resource_content_id_eq).to_i

    translations = translations.sort_by { |t| t[:resource] && t[:resource].id == selected ? 0 : 1 }
    imported = translations.select do |t|
      t[:total_count] == t[:imported_count]
    end

    div "Total Resources: #{translations.size}"
    div "Imported: #{imported.size}"

    div class: 'd-flex w-100 flex-column sidebar-item' do
      translations.each do |t|
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
            span(link_to 'Filter', "/cms/draft_translations?q%5Bresource_content_id_eq%5D=#{resource_content.id}", class: 'btn btn-sm btn-info text-white')

            issue_count = AdminTodo.where(resource_content_id: resource_content.id).count

            if can?(:manage, :draft_content) || current_user.super_admin?
              span(link_to 'Sync', import_draft_cms_resource_content_path(resource_content), method: 'put', class: 'btn btn-sm btn-success text-white', data: { confirm: 'Are you sure to re-sync this translation from QuranEnc?' })
              span(link_to 'Approve', import_draft_cms_resource_content_path(resource_content, approved: true), method: 'put', class: 'btn btn-sm btn-danger text-white', data: { confirm: 'Are you sure to import this translation?' })

              if issue_count.positive?
                span(link_to "Issues #{issue_count}", "/cms/admin_todos?q%5Bresource_content_id_eq%5D=#{resource_content.id}&order=id_desc", class: 'btn btn-sm btn-warning text-white')
              end

              span(link_to 'Delete', import_draft_cms_resource_content_path(resource_content, remove_draft: true), method: 'put', class: 'btn btn-sm btn-danger text-white', data: { confirm: 'Are you sure to remove draft translations?' })
            end
          end
        end
      end
    end
  end

  permit_params do
    %i[
      draft_text
    ]
  end
end
