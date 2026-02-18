# == Schema Information
#
# Table name: word_synonyms
#
#  id         :integer          not null, primary key
#  synonym_id :integer
#  word_id    :integer
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_word_synonyms_on_synonym_id_and_word_id  (synonym_id,word_id)
#

class WordSynonym < ApplicationRecord
  belongs_to :word, optional: true
  belongs_to :synonym, optional: true
end
