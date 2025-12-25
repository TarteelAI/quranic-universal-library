# == Schema Information
#
# Table name: word_mistakes
#
#  id            :bigint           not null, primary key
#  char_end      :integer
#  char_start    :integer
#  mistake_count :integer          default(0), not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  word_id       :integer          not null
#
# Indexes
#
#  index_word_mistakes_on_word_id                              (word_id)
#  index_word_mistakes_on_word_id_and_char_start_and_char_end  (word_id,char_start,char_end)
#
class WordMistake < QuranApiRecord
  belongs_to :word
  before_save :normalize_char_range

  scope :for_page, ->(page_number) { where(word_id: MushafWord.where(page_number: page_number).select(:word_id)) }

  def full_word?
    char_start.nil? && char_end.nil?
  end

  def partial_word?
    !full_word?
  end

  private

  def normalize_char_range
    return if char_start.nil? || char_end.nil?
    
    if char_start > char_end
      self.char_start, self.char_end = char_end, char_start
    end
  end

  def char_range_validity
    return unless char_start.present? || char_end.present?
    
    if char_start.nil? || char_end.nil?
      errors.add(:base, 'Both char_start and char_end must be present for partial words')
      return
    end

    if char_start < 0
      errors.add(:char_start, 'must be greater than or equal to 0')
    end

    if char_end < 0
      errors.add(:char_end, 'must be greater than or equal to 0')
    end

    normalized_start = [char_start, char_end].min
    normalized_end = [char_start, char_end].max

    if normalized_start == normalized_end
      errors.add(:base, 'char_start and char_end cannot be equal')
    end

    if word
      word_text = word.text_qpc_hafs || word.text_uthmani || word.text_indopak || ''
      text_length = word_text.length
      if text_length > 0 && normalized_end > text_length
        errors.add(:char_end, "cannot exceed word length (#{text_length})")
      end
    end
  end
end
