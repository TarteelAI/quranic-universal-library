# frozen_string_literal: true

ActiveAdmin.register Morphology::GrammarTerm do
  menu parent: 'Morphology'
  actions :all, except: :destroy

  filter :category
  filter :term

  searchable_select_options(
    scope: Morphology::GrammarTerm,
    text_attribute: :humanize,
    filter: lambda do |term, scope|
      scope.ransack(
        arabic_grammar_name_cont: term,
        english_grammar_name_cont: term,
        m: 'or'
      ).result
    end
  )

  permit_params do
    %i[category term arabic_description arabic_grammar_name english_description english_grammar_name urdu_description
       urdu_grammar_name]
  end

  index do
    selectable_column
    id_column

    column :category
    column :term
  end
end
