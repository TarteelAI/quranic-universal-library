class QuranWordFinder
  def initialize(scope=nil)
    @scope = scope || base_scope
  end

  def find_by_letters(letters)
    query =  "%#{letters}%"

    @scope.where(
      "text_uthmani LIKE :query OR text_imlaei LIKE :query OR text_qpc_hafs LIKE :query OR text_qpc_nastaleeq_hafs LIKE :query",
      query: query
    )
  end

  # Find words that start and end with specific letters in any of the text attributes
  def find_by_start_and_end(starting_letter, ending_letter)
    regex_pattern = "^#{starting_letter}.*#{ending_letter}$"
    @scope.where(
      "text_uthmani ~ ? OR text_imlaei ~ ? OR text_qpc_hafs ~ ? OR text_qpc_nastaleeq_hafs ~ ?",
      regex_pattern, regex_pattern, regex_pattern, regex_pattern
    )
  end

  def find_by_starting_letter(starting_letter)
    regex_pattern = "^#{starting_letter}"
    @scope.where(
      "text_uthmani ~ ? OR text_imlaei ~ ? OR text_qpc_hafs ~ ? OR text_qpc_nastaleeq_hafs ~ ?",
      regex_pattern, regex_pattern, regex_pattern, regex_pattern
    )
  end

  def find_by_ending_letter(ending_letter)
    regex_pattern = "#{ending_letter}$"
    @scope.where(
      "text_uthmani ~ ? OR text_imlaei ~ ? OR text_qpc_hafs ~ ? OR text_qpc_nastaleeq_hafs ~ ?",
      regex_pattern, regex_pattern, regex_pattern, regex_pattern
    )
  end
  protected
  def base_scope
    Word.unscoped
  end
end
