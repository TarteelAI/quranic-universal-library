# == Schema Information
#
# Table name: roots
#
#  id                    :integer          not null, primary key
#  arabic_trilateral     :string
#  dictionary_image_path :string
#  en_translations       :jsonb
#  english_trilateral    :string
#  text_clean            :string
#  text_uthmani          :string
#  uniq_words_count      :integer
#  ur_translations       :jsonb
#  value                 :string
#  words_count           :integer
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#
# Indexes
#
#  index_roots_on_arabic_trilateral   (arabic_trilateral)
#  index_roots_on_english_trilateral  (english_trilateral)
#  index_roots_on_text_clean          (text_clean)
#  index_roots_on_text_uthmani        (text_uthmani)
#

class Root < QulQuranRecord
  has_paper_trail on: %i[update destroy], ignore: %i[created_at updated_at]

  has_many :words
  has_many :verses, through: :words

  def to_s
    text_uthmani
  end

  def english_translations
    Oj.load(en_translations.to_s) || []
  rescue Exception => e
    []
  end

  def urdu_translations
    Oj.load(ur_translations.to_s) || []
  rescue Exception => e
    []
  end

  def save_suggestions(params, user)
    # Letters can be typed with or without the spaces between them
    arabic = params[:arabic_trilateral].to_s.gsub(/\s+/, '').chars.join(' ')
    english = params[:english_trilateral].to_s.strip
    errors.add(:base, 'Root letters are required') if arabic.blank?
    errors.add(:base, 'Root letters must be Arabic letters, separated by spaces') if arabic.present? && arabic !~ /\A[\p{Arabic}]( [\p{Arabic}]){1,4}\z/
    errors.add(:base, 'English letters are required') if english.blank?

    draft = Draft::Root.new(
      root_id: id,
      user: user,
      comment: params[:comment].to_s.strip.presence,
      current_arabic_trilateral: arabic_trilateral,
      draft_arabic_trilateral: arabic,
      current_english_trilateral: english_trilateral,
      draft_english_trilateral: english,
      current_text_uthmani: text_uthmani,
      draft_text_uthmani: params[:text_uthmani].to_s.strip,
      current_en_meanings: english_translations,
      draft_en_meanings: split_meanings(params[:en_meanings]),
      current_ur_meanings: urdu_translations,
      draft_ur_meanings: split_meanings(params[:ur_meanings])
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

  private

  # "Walk, Foot" => ["Walk", "Foot"]
  def split_meanings(text)
    text.to_s.split(/[,،]/).map(&:strip).compact_blank.uniq
  end
end
