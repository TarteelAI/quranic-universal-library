# frozen_string_literal: true

ActiveAdmin.register WordLemma do
  menu parent: 'Grammar'
  permit_params :word_id, :lemma_id

  filter :lemma_id, as: :searchable_select,
         ajax: { resource: Lemma }

  filter :word_id, as: :searchable_select,
         ajax: { resource: Word }

  form do |f|
    f.inputs 'WordLemma Details' do
      f.input :lemma_id
      f.input :word_id
    end

    f.actions
  end

  def scoped_collection
    super.includes :word, :lemma
  end

  index do
    id_column
    column :word_id do |resource|
      word = resource.word
      link_to(word.text_qpc_hafs, admin_word_path(word), class: 'quran-text qpc-hafs')
    end

    column :lemma_id do |resource|
      lemma = resource.lemma
      link_to(lemma.text_clean, admin_lemma_path(lemma), class: 'quran-text qpc-hafs')
    end

    actions
  end
end
