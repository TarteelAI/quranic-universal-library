module Morphology
  class DictionaryTermTranslation < QuranApiRecord
    self.table_name = 'morphology_dictionary_term_translations'

    belongs_to :term, class_name: 'Morphology::DictionaryTerm', foreign_key: :term_id

    validates :locale, presence: true
  end
end

