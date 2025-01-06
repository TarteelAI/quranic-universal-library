class QuranWordFinder
  def initialize(scope=nil)
    @scope = scope || base_scope
  end

  def find_by_letters(letters)
    query =  "%#{letters}%"

    @scope.where(
      "text_uthmani LIKE :query OR text_imlaei LIKE :query OR text_qpc_hafs LIKE :query OR text_qpc_nastaleeq_hafs LIKE :query OR text_indopak LIKE :query",
      query: query
    )
  end

  # Find words that start and end with specific letters in any of the text attributes
  def find_by_start_and_end(starting_letter, ending_letter)
    query = "^#{starting_letter}.*#{ending_letter}$"

    @scope.where(
      "text_uthmani ~ :query OR text_imlaei ~ :query OR text_qpc_hafs ~ :query OR text_qpc_nastaleeq_hafs ~ :query OR text_indopak ~ :query",
      query: query
    )
  end

  def find_by_letter_range(starting_letter, ending_letter)
    query = "%#{starting_letter}%#{ending_letter}%"
    @scope.where(
      "text_uthmani ilike :query OR text_imlaei ilike :query OR text_qpc_hafs ilike :query OR text_qpc_nastaleeq_hafs ilike :query OR text_indopak ilike :query",
      query: query
    )
  end

  def find_by_starting_letter(starting_letter)
    query = "^#{starting_letter}"
    @scope.where(
      "text_uthmani ~ :query OR text_imlaei ~ :query OR text_qpc_hafs ~ :query OR text_qpc_nastaleeq_hafs ~ :query OR text_indopak ~ :query",
      query: query
    )
  end

  def find_by_ending_letter(ending_letter)
    query = "#{ending_letter}$"

    @scope.where(
      "text_uthmani ~ :query OR text_imlaei ~ :query OR text_qpc_hafs ~ :query OR text_qpc_nastaleeq_hafs ~ :query OR text_indopak ~ :query",
      query: query
    )
  end

  protected
  def base_scope
    Word.unscoped
  end
end
