ActiveAdmin.register Morphology::PhraseVerse do
  menu parent: 'Morphology'

  filter :verse, as: :searchable_select,
         ajax: { resource: Verse }
  filter :matched_words_count
  filter :approved
  filter :review_status
  filter :created_at

  action_item :approve, only: :show do
    link_to approve_cms_morphology_phrase_verse_path(resource), method: :put, data: { confirm: 'Are you sure?' } do
      resource.approved? ? 'Un Approve!' : 'Approve!'
    end
  end

  member_action :create_matching_ayah, method: 'put' do
    @matching_verse = resource.create_matching_ayah

    render partial: 'admin/matching_verse_link'
  end

  member_action :approve, method: 'put' do
    if params[:all] && params[:toggle]
      Morphology::PhraseVerse.where(phrase_id: params[:id]).update_all(approved: params[:toggle] == '1')
    else
      resource.toggle_approve!
    end

    if request.xhr?
      render partial: 'admin/update_morphology_resource_approval'
    else
      redirect_to [:cms, resource], notice: resource.approved? ? 'Approved successfully' : 'Un approved successfully'
    end
  end

  show do
    attributes_table do
      row :id
      row :approved
      row :review_status
      row :verse
      row :phrase do
        link_to resource.phrase.text_qpc_hafs, [:cms, resource.phrase], class: 'qpc-hafs'
      end
      row :text do
        span resource.text, class: 'qpc-hafs'
      end
      row :word_position_from
      row :word_position_to
      row :missing_word_positions
      row :similar_words_position
      row :matched_words_count
      row :created_at
      row :updated_at
    end
  end

  permit_params do
    [
      :phrase_id,
      :verse_id,
      :word_position_from,
      :word_position_to,
      :matched_words_count,
      :approved,
      missing_word_positions: [],
      similar_words_position: [],
    ]
  end
end
