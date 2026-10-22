class TajweedWordsPresenter < ApplicationPresenter
  def word
    return @word if defined?(@word)

    @word = Word.find_by(location: params[:id])
  end

  def tajweed_word
    return @tajweed_word if defined?(@tajweed_word)

    @tajweed_word = word && TajweedWord.find_by(word_id: word.id)
  end

  def tajweed_rule
    @tajweed_rule ||= TajweedRules.new('new').documentation[params[:rule].to_s.to_sym]
  end

  def meta_title
    "Tajweed Rules Annotation Tool"
  end

  def meta_description
    "Review and correct the Tajweed rules embedded in Quranic text. Use suggestions to add missing rules or fix incorrect ones for accurate Tajweed annotation."
  end

  def meta_keywords
    'Tajweed rules annotation tool, Tajweed rules online, Quran Tajweed editor, Tajweed correction tool, Online Tajweed editor, Tajweed annotation platform, Fix Tajweed mistakes, Advanced Quran Tajweed'
  end
end
