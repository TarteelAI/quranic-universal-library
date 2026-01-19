module Morphology
  class DictionaryTerm < QuranApiRecord
    self.table_name = 'morphology_dictionary_terms'

    has_many :translations, class_name: 'Morphology::DictionaryTermTranslation', foreign_key: :term_id, dependent: :destroy

    validates :category, presence: true
    validates :key, presence: true, uniqueness: { scope: :category }

    def translation_for(locale)
      translations.find_by(locale: locale.to_s) || translations.find_by(locale: I18n.default_locale.to_s)
    end
  end
end

