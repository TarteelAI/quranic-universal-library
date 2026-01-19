# frozen_string_literal: true

ActiveAdmin.register Morphology::GrammarTerm do
  menu parent: 'Morphology'
  actions :all, except: :destroy

  filter :category
  filter :term
  filter :arabic
  filter :english
  filter :term_type, as: :select, collection: proc { [['POS Tag', 1], ['Edge Relation', 2]] }

  searchable_select_options(
    scope: Morphology::GrammarTerm,
    text_attribute: :humanize,
    filter: lambda do |term, scope|
      scope.ransack(
        term_cont: term,
        arabic_cont: term,
        english_cont: term,
        m: 'or'
      ).result
    end
  )

  permit_params do
    %i[category term  arabic english term_type]
  end

  index do
    id_column

    column :category
    column :term
    column :arabic
    column :english
    column :term_type
    actions
  end
end
