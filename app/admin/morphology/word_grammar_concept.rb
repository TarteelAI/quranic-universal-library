# frozen_string_literal: true

ActiveAdmin.register Morphology::WordGrammarConcept do
  menu parent: 'Morphology'
  actions :index, :show
  includes :word, :grammar_concept

  filter :word_id, as: :numeric
  filter :grammar_concept_id, as: :numeric

  index do
    id_column
    column :word do |resource|
      resource.word && link_to(resource.word.location, [:cms, resource.word])
    end
    column :grammar_concept do |resource|
      resource.grammar_concept && link_to(resource.grammar_concept.english.presence || resource.grammar_concept.arabic, [:cms, resource.grammar_concept])
    end
    actions
  end

  show do
    attributes_table do
      row :id
      row :word do |resource|
        resource.word && link_to(resource.word.location, [:cms, resource.word])
      end
      row :grammar_concept
      row :created_at
      row :updated_at
    end
  end
end
