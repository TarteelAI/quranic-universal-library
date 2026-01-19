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

class Morphology::GrammarTerm < QuranApiRecord
  has_many :word_segments, class_name: 'Morphology::WordSegment'
  has_many :words, through: :word_segments, class_name: 'Morphology::Word'
  has_many :translations, class_name: 'Morphology::GrammarTermTranslation', foreign_key: :grammar_term_id, dependent: :destroy

  def humanize
    "#{english_grammar_name} - #{arabic_grammar_name}"
  end

  def to_s
    "#{category}:#{term}"
  end

  def translation_for(locale)
    translations.find_by(locale: locale.to_s) || translations.find_by(locale: I18n.default_locale.to_s)
  end

  def fallback_title_for(locale)
    case locale.to_s
    when 'ar'
      arabic_grammar_name
    when 'ur'
      urdu_grammar_name
    else
      english_grammar_name
    end
  end

  def fallback_description_for(locale)
    case locale.to_s
    when 'ar'
      arabic_description
    when 'ur'
      urdu_description
    else
      english_description
    end
  end
end
