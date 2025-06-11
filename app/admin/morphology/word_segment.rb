# frozen_string_literal: true

ActiveAdmin.register Morphology::WordSegment do
  menu parent: 'Morphology'
  actions :all, except: :destroy
  includes :word

  filter :word,
         as: :searchable_select,
         ajax: { resource: Word }
  filter :part_of_speech_key
  filter :pos_tags
  filter :verb_form

  searchable_select_options(
    scope: Morphology::WordSegment,
    text_attribute: :humanize,
    filter: lambda do |term, scope|
      scope.ransack(
        location_cont: term,
      ).result
    end
  )

  permit_params do
    %i[
    text_uthmani position
    part_of_speech_key
    part_of_speech_name pos_tags
    grammar_term_desc_arabic
    grammar_term_desc_english
    verb_form
    lemma_name
       lemma_id
       root_name
       root_id
       topic_id
       grammar_concept_id
       grammar_role
       grammar_sub_role
  ]
  end

  index do
    selectable_column
    id_column
    column :word_id do |resource|
      link_to resource.word.location, [:cms, resource.word]
    end
    column :position

    column :part_of_speech_key
    column :pos_tags

    column :text_uthmani
    column :root_name
    column :verb_form
  end

  form do |f|
    f.inputs 'Morphology Word Segment Detail' do
      f.input :text_uthmani
      f.input :position
      f.input :pos_tags
      f.input :part_of_speech_key
      f.input :part_of_speech_name

      f.input :grammar_term_desc_arabic
      f.input :grammar_term_desc_english
      f.input :verb_form

      f.input :lemma_name
      f.input :lemma_id,
              as: :searchable_select,
              ajax: { resource: Lemma }

      f.input :root_name
      f.input :root_id,
              as: :searchable_select,
              ajax: { resource: Root }
      f.input :topic_id,
              as: :searchable_select,
              ajax: { resource: Topic }
      f.input :grammar_concept, as: :searchable_select,
              ajax: { resource: Root }
      f.input :grammar_role
      f.input :grammar_sub_role
      f.input :grammar_term, as: :searchable_select,
              ajax: { resource: Morphology::GrammarTerm }
    end

    f.actions
  end
end
