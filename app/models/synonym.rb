# == Schema Information
#
# Table name: synonyms
#
#  id                :bigint           not null, primary key
#  approved_synonyms :jsonb
#  synonyms          :text
#  text              :string
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#

class Synonym < ApplicationRecord
  scope :where_synonyms_cont, lambda { |synonym|
    where('synonyms like ?', "%#{synonym}%")
  }

  serialize :synonyms, Array

  has_many :word_synonyms, class_name: 'WordSynonym'

  def self.ransackable_scopes(*)
    %i[where_synonyms_cont]
  end

  def words
    # Word is from quran db, can't use joins here.
    Word.where id: word_synonyms.pluck(:word_id)
  end

  def synonyms=(text)
    text = text.is_a?(String) ? JSON.parse(text) : text

    write_attribute(:synonyms, text)
  end
end
