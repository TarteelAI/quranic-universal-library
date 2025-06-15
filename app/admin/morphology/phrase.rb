ActiveAdmin.register Morphology::Phrase do
  menu parent: 'Morphology'
  filter :id
  filter :text_qpc_hafs_simple
  filter :approved
  filter :review_status
  filter :chapters_count
  filter :verses_count
  filter :occurrence
  filter :words_count
  filter :source_verse, as: :searchable_select,
         ajax: { resource: Verse }
  filter :created_at
  filter :updated_at

  action_item :export_csv, only: :index, if: -> { can? :download, :from_admin } do
    link_to 'Export CSV', export_approved_cms_morphology_phrases_path(format: :json)
  end

  action_item :fix, only: :show do
    link_to 'View in Phrase tool', "/morphology_phrases/#{resource.id}", target: '_blank'
  end

  collection_action :export_approved, method: :get do
    authorize! :download, :from_admin
    export_service = ExportPhrase.new
    file = export_service.execute

    send_file file, filename: 'phrases.zip'
  end

  action_item :approve, only: :show, if: -> { can? :update, resource } do
    link_to approve_cms_morphology_phrase_path(resource), method: :put, data: { confirm: 'Are you sure?' } do
      resource.approved? ? 'Un Approve!' : 'Approve!'
    end
  end

  member_action :approve, method: 'put' do
    authorize! :update, resource

    resource.toggle_approve!
    redirect_to [:cms, resource], notice: resource.approved? ? 'Approved successfully' : 'Un approved successfully'
  end

  index do
    id_column
    column :text_simple do |resource|
      resource.text_qpc_hafs_simple
    end

    column :approved
    column :chapters_count
    column :verses_count
    column :occurrence
    column :words_count
    column :created_at
    column :updated_at
  end

  show do
    attributes_table do
      row :id
      row :approved
      row :review_status
      row :text_simple do
        div resource.text_qpc_hafs_simple, class: 'quran-text qpc-hafs'
      end
      row :text_qpc_hafs do
        div resource.text_qpc_hafs, class: 'quran-text qpc-hafs'
      end
      row :source_verse do
        div link_to(resource.source_verse.verse_key, [:cms, resource.source_verse]) if resource.source_verse
      end
      row :word_position_from
      row :word_position_to

      row :verses_count
      row :chapters_count
      row :occurrence
      row :words_count
      row :created_at
      row :updated_at
    end

    chapters = resource.chapters
    verses = resource.verses

    panel 'Chapters' do
      div 'data-controller': 'peity', 'data-chart': 'line' do
        (1..114).to_a.map do |c|
          chapters[c.to_i] ? chapters[c.to_i][:count] : 0
        end.join(',')
      end

      chapters.values.each do |c|
        span class: 'btn btn-info m-1' do
          span c[:chapter].id
          span c[:chapter].name_simple
          span c[:count], class: 'badge text-bg-secondary bg-success'
        end
      end
    end

    panel 'Related Verses' do
      if (can? :update, Morphology::MatchingVerse)
        div do
          span do
            link_to 'Approve all', approve_cms_morphology_phrase_verse_path(resource, all: true, toggle: '1'),
                    method: :put, class: 'btn btn-primary btn-sm text-white', data: { remote: true, confirm: 'Are you sure?' }
          end

          span do
            link_to 'Disapprove all', approve_cms_morphology_phrase_verse_path(resource, all: true, toggle: '0'),
                    method: :put, class: 'btn btn-primary btn-sm text-white', data: { remote: true, confirm: 'Are you sure?' }
          end
        end
      end

      table border: 1 do
        thead do
          th 'Id'
          th 'Key'
          th 'Actions'
          th 'Text', colspan: 2
        end

        tbody do
          resource.phrase_verses.each do |v|
            verse = verses[v.verse_id]

            tr do
              td link_to v.id, [:cms, v]
              td link_to verse.verse_key, [:cms, verse]
              td  do
                status_tag v.approved?

                div class: 'd-flex flex-column' do
                if(can? :update, Morphology::MatchingVerse)
                    span class: 'my-2' do
                      link_to approve_cms_morphology_phrase_verse_path(v),
                              class: "btn #{v.approved? ? 'btn-danger' : 'btn-success'} btn-sm text-white",
                              method: :put,
                              data: { remote: true, confirm: 'Are you sure?' } do
                        v.approved? ? 'Un Approve!' : 'Approve!'
                      end
                    end

                    if resource.source_verse_id && v.verse_id != resource.source_verse_id
                      span id: dom_id(v) do
                        link_to create_matching_ayah_cms_morphology_phrase_verse_path(v), method: :put,
                                class: 'btn btn-sm btn-info text-white', data: { remote: true, confirm: 'Are you sure?' } do
                          'Create Matching ayah'
                        end
                    end
                  end
                end
                end
              end

              td class: 'quran-text qpc-hafs' do
                verse.words.map do |w|
                  span w.text_qpc_hafs,
                       class: "#{
                         if w.position >= v.word_position_from.to_i && w.position <= v.word_position_to.to_i
                           'text-success'
                         end}"
                end
              end
            end
          end
        end
      end
    end

    panel 'Similar phrases' do
      table border: 1 do
        thead do
          th 'Id'
          th 'Status'
          td 'Approved?'
          td 'Cccurrence'
          th 'Key'
          th 'Text', colspan: 2
        end

        tbody do
          resource.similar_phrases.each do |phrase|
            tr do
              td link_to(phrase.id, [:cms, phrase])
              td phrase.review_status
              td phrase.approved? ? 'Yes' : 'No'
              td phrase.occurrence
              td phrase.source_verse.verse_key
              td phrase.text_qpc_hafs, class: 'qpc-hafs'
            end
          end
        end
      end
    end

    active_admin_comments
  end

  form do |f|
    f.inputs 'Phrase detail' do
      f.input :source_verse_id,
              as: :searchable_select,
              ajax: { resource: Verse }

      f.input :text_qpc_hafs
      f.input :text_qpc_hafs_simple
      f.input :word_position_from
      f.input :word_position_to
      f.input :occurrence
    end

    f.actions
  end

  permit_params do
    %i[
      source_verse_id
      text_qpc_hafs_simple
      text_qpc_hafs
      word_position_from
      word_position_to
      occurrence
      approved
    ]
  end
end
