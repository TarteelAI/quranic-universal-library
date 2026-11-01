# == Schema Information
#
# Table name: stems
#
#  id               :integer          not null, primary key
#  text_clean       :string
#  text_madani      :string
#  uniq_words_count :integer
#  words_count      :integer
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#

class Stem < QuranApiRecord
  has_paper_trail on: %i[update destroy], ignore: %i[created_at updated_at]

  has_many :words
  has_many :verses, through: :words

  # Harakat aren't always stored in the same order (shadda before fatha), compare normalized
  def self.find_by_text(text)
    where('normalize(text_madani, NFC) = ?', text.to_s.strip.unicode_normalize(:nfc)).first
  end

  def to_s
    text_madani
  end

  def save_suggestions(params, user)
    madani = params[:text_madani].to_s.strip
    clean = params[:text_clean].to_s.strip
    errors.add(:base, 'Stem is required') if madani.blank?
    errors.add(:base, 'Stem without harakat is required') if clean.blank?
    errors.add(:base, 'Stem must be written in Arabic') if "#{madani}#{clean}".match?(/[^\s\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF]/)

    draft = Draft::Stem.new(
      stem_id: id,
      user: user,
      comment: params[:comment].to_s.strip.presence,
      current_text_madani: text_madani,
      draft_text_madani: madani,
      current_text_clean: text_clean,
      draft_text_clean: clean
    )
    errors.add(:base, 'Nothing was changed') if errors.empty? && draft.matches_current?
    return false if errors.any?

    draft.save(validate: false)
  end

  def update_stats
    update_columns(
      words_count: words.count,
      uniq_words_count: words.map(&:text_imlaei_simple).uniq.count
    )
  end
end
