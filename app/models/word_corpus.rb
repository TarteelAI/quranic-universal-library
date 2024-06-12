# == Schema Information
#
# Table name: word_corpus
#
#  description     :string
#  image_src       :string
#  location        :string
#  segment         :json
#  transliteration :string
#  corpus_id       :integer          not null, primary key
#  word_id         :integer
#
# Indexes
#
#  index_quran.word_corpus_on_word_id  (word_id)
#

class WordCorpus < QuranApiRecord
  belongs_to :word
end
