class Morphology::Sentence < QuranApiRecord
  has_many :word_tokens,
           -> { order(:position_in_sentence) },
           class_name: 'Morphology::WordToken',
           foreign_key: :sentence_id

  belongs_to :chapter, optional: true
  belongs_to :first_verse, class_name: 'Verse', optional: true
  belongs_to :last_verse, class_name: 'Verse', optional: true

  def verse_range
    return if first_verse.blank?

    if first_verse_id == last_verse_id
      first_verse.verse_key
    else
      "#{first_verse.verse_key} - #{last_verse.verse_key}"
    end
  end

  def humanize
    [sentence_number, verse_range && "(#{verse_range})"].compact.join(' ')
  end
end
