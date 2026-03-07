# == Schema Information
#
# Table name: morphology_derived_words
#
#  id                 :integer          not null, primary key
#  verse_id           :integer
#  word_id            :integer
#  derived_word_id    :integer
#  word_verb_from_id  :integer
#  form_name          :string
#  en_transliteration :string
#  en_translation     :string
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#
# Indexes
#
#  index_morphology_derived_words_on_derived_word_id    (derived_word_id)
#  index_morphology_derived_words_on_verse_id           (verse_id)
#  index_morphology_derived_words_on_word_id            (word_id)
#  index_morphology_derived_words_on_word_verb_from_id  (word_verb_from_id)
#

class Morphology::DerivedWord < QuranApiRecord
  belongs_to :verse
  belongs_to :word, optional: true
  belongs_to :morphology_word, class_name: 'Morphology::Word', foreign_key: :word_id, optional: true
  belongs_to :derived_word, class_name: 'Morphology::Word', optional: true
  belongs_to :word_verb_from, optional: true, class_name: 'Morphology::WordVerbForm'
  belongs_to :resource_content, optional: true
  belongs_to :word_verb_from, optional: true, class_name: 'Morphology::WordVerbForm'
end
