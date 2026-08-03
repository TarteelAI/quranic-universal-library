class Morphology::WordToken < QuranApiRecord
  belongs_to :sentence, class_name: 'Morphology::Sentence', optional: true
  belongs_to :word, optional: true
  belongs_to :morphology_word, class_name: 'Morphology::Word', optional: true
  belongs_to :root, optional: true
  belongs_to :lemma, optional: true
  belongs_to :head_token, class_name: 'Morphology::WordToken', optional: true
  has_many :dependent_tokens, class_name: 'Morphology::WordToken', foreign_key: :head_token_id

  enum :token_type, {
    surface: 0,
    implicit_pronoun: 1,
    elided: 2
  }

  def part_of_speech
    Corpus::Morphology::PartOfSpeech.parse(pos_key) if pos_key.present?
  end

  def rel_label_name
    return if rel_label.blank?

    base = I18n.t("morphology.edge_relations.#{rel_label}", default: rel_label)
    [base, rel_governor].compact_blank.join(' ')
  end

  def pos_name
    return if pos_key.blank?

    I18n.t("morphology.pos_tags.#{pos_key}", default: pos_key)
  end

  def humanize
    "#{location || token_type} - #{text_uthmani}"
  end
end
