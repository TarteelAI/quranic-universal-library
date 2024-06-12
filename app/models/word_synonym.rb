# == Schema Information
#
# Table name: word_synonyms
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  synonym_id :integer
#  word_id    :integer
#
# Indexes
#
#  index_word_synonyms_on_synonym_id_and_word_id  (synonym_id,word_id)
#

class WordSynonym < ApplicationRecord
  belongs_to :word
  belongs_to :synonym
end
