class WordTextProofreadingsPresenter < ApplicationPresenter
  def words_with_tashkeel_differences
    col_a = params[:col_a].to_s.strip
    col_b = params[:col_b].to_s.strip

    regex = '[^\u064B-\u065F\u0670\u06D6-\u06ED]'

    words = Word.words.select(
      :id,
      col_a,
      col_b,
      "LENGTH(REGEXP_REPLACE(#{col_a}, '#{regex}', '', 'g')) AS #{col_a}_tashkeel_count",
      "LENGTH(REGEXP_REPLACE(#{col_b}, '#{regex}', '', 'g')) AS #{col_b}_tashkeel_count"
    ).where(
          "LENGTH(REGEXP_REPLACE(#{col_a}, '#{regex}', '', 'g')) <> LENGTH(REGEXP_REPLACE(#{col_b}, '#{regex}', '', 'g'))"
    ).order(:id)

    paginate(words)
  end

  def meta_title
    if index?
      "Quranic Script & Fonts Proofreading Tool - Verse List"
    elsif show?
      "Quranic Script & Fonts Proofreading Tool - Verse #{current_ayah.verse_key}"
    elsif params[:action] == 'compare_words'
      "Quranic Script & Fonts Proofreading Tool - Compare Words with '#{@char}'"
    else
      "Quranic Script & Fonts Proofreading Tool"
    end
  end

  def meta_description
    "Review and correct Quranic script issues across various fonts, focusing on Tashkeel accuracy. Proofread ayahs and individual words to ensure consistency and proper rendering in different script styles."
  end

  def meta_keywords
    'Quran script proofreading, Tashkeel correction, Quranic fonts review, Arabic script checker, Quran font compatibility, Quran orthography tool'
  end

  def current_ayah
    @current_ayah ||= Verse.find(params[:id])
  end
end
