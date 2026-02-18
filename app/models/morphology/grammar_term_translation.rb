class Morphology::GrammarTermTranslation < QuranApiRecord
  self.table_name = 'morphology_grammar_term_translations'

  belongs_to :grammar_term, class_name: 'Morphology::GrammarTerm', foreign_key: :grammar_term_id

  validates :locale, presence: true
end

