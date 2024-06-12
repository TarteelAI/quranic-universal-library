# frozen_string_literal: true

# == Schema Information
#
# Table name: morphology_grammar_terms
#
#  id                   :bigint           not null, primary key
#  arabic_description   :text
#  arabic_grammar_name  :string
#  category             :string
#  english_description  :text
#  english_grammar_name :string
#  term                 :string
#  urdu_description     :text
#  urdu_grammar_name    :string
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#
# Indexes
#
#  index_morphology_grammar_terms_on_category  (category)
#  index_morphology_grammar_terms_on_term      (term)
#
ActiveAdmin.register Morphology::GrammarTerm do
  menu parent: 'Morphology'
  actions :all, except: :destroy

  filter :category
  filter :term

  searchable_select_options(scope: Morphology::GrammarTerm,
                            text_attribute: :humanize,
                            filter: lambda do |term, scope|
                              scope.ransack(
                                arabic_grammar_name_cont: term,
                                english_grammar_name_cont: term,
                                m: 'or'
                              ).result
                            end)

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
