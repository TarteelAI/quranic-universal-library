# == Schema Information
#
# Table name: morphology_words
#
#  id                      :integer          not null, primary key
#  word_id                 :integer
#  verse_id                :integer
#  grammar_pattern_id      :integer
#  grammar_base_pattern_id :integer
#  words_count_for_root    :integer
#  words_count_for_lemma   :integer
#  words_count_for_stem    :integer
#  location                :string
#  description             :text
#  case                    :string
#  case_reason             :string
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#
# Indexes
#
#  index_morphology_words_on_grammar_base_pattern_id  (grammar_base_pattern_id)
#  index_morphology_words_on_grammar_pattern_id       (grammar_pattern_id)
#  index_morphology_words_on_location                 (location)
#  index_morphology_words_on_verse_id                 (verse_id)
#  index_morphology_words_on_word_id                  (word_id)
#

class Morphology::Word < QuranApiRecord
  belongs_to :word, class_name: '::Word', optional: true
  belongs_to :verse
  belongs_to :grammar_pattern, class_name: 'Morphology::GrammarPattern', optional: true
  belongs_to :grammar_base_pattern, class_name: 'Morphology::GrammarPattern', optional: true
  belongs_to :resource_content, optional: true
  belongs_to :grammar_base_pattern, class_name: 'Morphology::GrammarPattern', optional: true

  has_many :derived_words, class_name: 'Morphology::DerivedWord'
  has_many :verb_forms, class_name: 'Morphology::WordVerbForm'
  has_many :word_segments, class_name: 'Morphology::WordSegment'
  has_many :word_grammar_concepts, class_name: 'Morphology::WordGrammarConcept'
  has_many :grammar_concepts, class_name: 'Morphology::GrammarConcept', through: :word_grammar_concepts

  def text
    word.text_qpc_hafs
  end

  def humanize
    "#{location} - #{text}"
  end

  def position
    word.position
  end
end
