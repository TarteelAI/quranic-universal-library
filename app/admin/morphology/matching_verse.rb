ActiveAdmin.register Morphology::MatchingVerse do
  menu parent: 'Morphology'

  filter :chapter, as: :searchable_select,
         ajax: { resource: Chapter }

  filter :verse, as: :searchable_select,
         ajax: { resource: Verse }

  filter :matched_chapter, as: :searchable_select,
         ajax: { resource: Chapter }

  filter :matched_verse, as: :searchable_select,
         ajax: { resource: Verse }

  filter :words_count
  filter :matched_words_count
  filter :score
  filter :coverage
  filter :approved
  filter :created_at

  includes :matched_verse, :verse

  action_item :export_csv, only: :index, if: -> { can? :download, :from_admin } do
    link_to "Export CSV", export_csv_cms_morphology_matching_verses_path(format: :json), method: :post
  end

  collection_action :export_csv, method: :post do
    authorize! :download, :from_admin

    export_service = ExportMatchingAyah.new
    file = export_service.execute

    send_file file, filename: "matching_ayah.json", type: "application/json"
  end

  action_item :approve, only: :show do
    link_to approve_cms_morphology_matching_verse_path(resource), method: :put, data: { confirm: 'Are you sure?' } do
      resource.approved? ? 'Un Approve!' : 'Approve!'
    end
  end

  member_action :approve, method: 'put' do
    resource.toggle_approve!

    if request.xhr?
      render partial: 'admin/update_morphology_resource_approval'
    else
      redirect_to [:cms, resource], notice: resource.approved? ? 'Approved successfully' : 'Un approved successfully'
    end
  end

  index do
    id_column
    column :approved
    column :verse, sortable: :verse_id do |r|
      link_to r.verse.verse_key, [:cms, r.verse]
    end
    column :matched_verse, sortable: :matched_verse_id do |r|
      link_to r.matched_verse.verse_key, [:cms, r.matched_verse]
    end
    column :chapter, sortable: :chapter_id do |r|
      link_to r.chapter_id, cms_chapter_path(r.chapter_id)
    end
    column :matched_chapter, sortable: :matched_chapter_id do |r|
      link_to r.matched_chapter_id, cms_chapter_path(r.matched_chapter_id)
    end
    column :score
    column :coverage
    column :matched_word_positions
    actions
  end

  show do
    attributes_table do
      row :id
      row :approved
      row :chapter do
        c = resource.chapter
        link_to(c.name, [:cms, c])
      end

      row :matched_chapter do
        c = resource.matched_chapter
        link_to(c.name, [:cms, c])
      end

      row :verse do
        c = resource.verse

        div class: 'd-flex' do
          span link_to(c.verse_key, [:cms, c])
          span c.text_qpc_hafs, class: 'quran-text qpc-hafs'
        end
      end

      row :matched_verse do
        div class: 'd-flex' do
          c = resource.matched_verse
          positions = resource.matched_word_positions.map(&:to_i)

          span link_to(c.verse_key, [:cms, c])

          span do
          c.words.map do |w|
            span w.text_qpc_hafs, class: "quran-text qpc-hafs #{'text-success' if positions.include?(w.position)}"
          end
          end
        end
      end

      row :matched_words_count
      row :matched_word_positions
      row :score
      row :coverage
      row :words_count
      row :created_at
      row :updated_at

      other_matching_verses = resource.verse.get_matching_verses
      panel "Ayahs similar to #{resource.verse.verse_key} (#{other_matching_verses.size})", id: 'verse-words' do
        div class: 'd-flex' do
          span link_to('Approve all', '#'), class: 'me-2'
          span link_to('Unapprve all', '#')
        end

        table do
          thead do
            th '#'
            th 'Key'
            th 'Score'
            th 'Coverage'
            th 'Approved'
            th 'Text', colspan: 5
          end

          tbody do
            other_matching_verses.each_with_index do |matching, i|
              matching_verse = matching.is_source_verse?(resource.verse) ? matching.matched_verse : matching.verse
              positions = matching.matched_word_positions.map(&:to_i)

              tr do
                td "#{i + 1} - #{link_to matching_verse.id, [:cms, matching]}".html_safe
                td link_to(matching_verse.verse_key, [:cms, matching_verse])
                td matching.score
                td matching.coverage

                td do
                  status_tag matching.approved?

                  span do
                    link_to approve_cms_morphology_matching_verse_path(matching), method: :put, id: dom_id(matching), data: { remote: true, confirm: 'Are you sure?' } do
                      matching.approved? ? 'Un Approve!' : 'Approve!'
                    end
                  end
                end

                td class: 'quran-text qpc-hafs' do
                  matching_verse.words.map do |w|
                    span w.text_qpc_hafs, class: "#{'text-success' if positions.include?(w.position)}"
                  end
                end
              end
            end
          end
        end
      end
    end
  end

  form do |f|
    f.inputs 'Matching ayah detail' do
      f.input :verse_id,
              as: :searchable_select,
              ajax: { resource: Verse }

      f.input :matched_verse_id,
              as: :searchable_select,
              ajax: { resource: Verse }

      f.input :coverage
      f.input :score
      f.input :approved
      f.input :matched_word_positions
    end

    f.actions
  end

  permit_params do
    [
      :verse_id,
      :matched_verse_id,
      :coverage,
      :score,
      :approved,
      :matched_word_positions
    ]
  end
end

