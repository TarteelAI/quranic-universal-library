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

  action_item :previous_page, only: :show  do
    if item = resource.previous_ayah_translation
      link_to("Previous(#{item.verse.verse_key})", "/admin/draft_translations/#{item.id}", class: 'btn') if item
    end
  end

  action_item :import, only: :show do
    link_to import_admin_draft_translation_path(resource), method: :put, data: { confirm: 'Are you sure?' } do
      'Approve and update'
    end if !resource.imported?
  end

  action_item :next_page, only: :show do
    if item = resource.next_ayah_translation
      link_to "Next(#{item.verse.verse_key})", "/admin/draft_translations/#{item.id}", class: 'btn'
    end
  end

  member_action :import, method: 'put' do
    translation = resource.import!

    redirect_to [:admin, translation], notice: 'Draft translation is approved and imported successfully'
  end

  index do
    id_column
    column :text_matched
    column :need_review
    column :verse_id
    column :imported
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
      row :current_text, class: language_name, 'data-controller': 'translation' do
        resource.current_text.to_s.html_safe
      end
      row :draft_text, class: language_name, 'data-controller': 'translation', draft: true do
        resource.draft_text.to_s.html_safe
      end

      row :text_matched
      row :imported

      row :diff do
        div do
          div Diffy::Diff.new(resource.current_text.to_s, resource.draft_text.to_s, include_plus_and_minus_in_html: true).to_s(:html).html_safe
        end
      end

      row :verse do
        link_to(resource.verse.verse_key, [:admin, resource.verse])
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
              td link_to(foot_note.id, [:admin, foot_note])

              td class: language_name do
                foot_note.draft_text.to_s.html_safe
              end

              td class: language_name do
                foot_note.current_text.to_s.html_safe
              end

              td foot_note.text_matched? ? 'Yes' : 'No'
            end
          end
        end
      end
    end
  end

  sidebar 'Draft translations', only: :index do
    translations = Draft::Translation.new_translations
    selected = params.dig(:q, :resource_content_id_eq).to_i
    imported = Draft::Translation.imported_translations.pluck(:id)
    div "Total: #{translations.size}"
    div "Imported: #{imported.size}"

    div class: 'd-flex w-100 flex-column sidebar-item' do
      translations.each do |resource_content|
        div class: "w-100 p-1 flex-between border-bottom mb-3 #{'selected' if selected == resource_content.id}"  do
          div do
            span link_to(resource_content.id, [:admin, resource_content], target: 'blank')
            imported.include?(resource_content.id) ? span('imported', class: 'status_tag yes ms-2') : ''
          end
          div "#{resource_content.name}(#{resource_content.language_name})"

          div class: 'd-flex my-2 flex-between gap-2' do
            span(link_to 'Filter', "/admin/draft_translations?q%5Bresource_content_id_eq%5D=#{resource_content.id}", class: 'mb-2 btn btn-sm btn-info text-white')
            if can?(:manage, :draft_content) || current_user.super_admin?
              span(link_to 'Sync', import_draft_admin_resource_content_path(resource_content), method: 'put', class: 'btn btn-sm mb-2 btn-success text-white', data: {confirm: 'Are you sure to re sync this translations from QuranEnc?'})
              span(link_to 'Approve', import_draft_admin_resource_content_path(resource_content, approved: true), method: 'put', class: 'btn btn-sm btn-danger text-white', data: {confirm: 'Are you sure to import this translations?'})
              span(link_to 'Delete', import_draft_admin_resource_content_path(resource_content, remove_draft: true), method: 'put', class: 'btn btn-sm btn-danger text-white', data: {confirm: 'Are you sure to remove draft translations?'})
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
