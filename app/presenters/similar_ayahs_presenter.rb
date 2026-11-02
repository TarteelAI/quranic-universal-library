class SimilarAyahsPresenter < ApplicationPresenter
  FILTERS = { 'with' => 'Ayahs with similar ayahs', 'without' => 'Ayahs without similar ayahs' }.freeze

  def verses
    list = Verse.all
    list = list.where(chapter_id: params[:filter_chapter].to_i) if params[:filter_chapter].to_i > 0
    list = list.where(verse_number: params[:verse_number].to_i) if params[:verse_number].to_i > 0

    case params[:similar]
    when 'with'
      list = list.where(id: approved_matches.distinct.pluck(:verse_id))
    when 'without'
      list = list.where.not(id: approved_matches.distinct.pluck(:verse_id))
    end

    paginate(list.order(verse_index: sort_order))
  end

  # { verse_id => number of similar ayahs }
  def similar_counts(verses)
    approved_matches.where(verse_id: verses.map(&:id)).group(:verse_id).count
  end

  def verse
    @verse ||= Verse.find(params[:id])
  end

  # Approved similar ayahs, best first
  def matches
    @matches ||= with_verses(approved_matches.where(verse_id: verse.id))
  end

  # Found by the detector but not approved, a user can approve them
  def possible_matches
    @possible_matches ||= with_verses(Morphology::MatchingVerse.where(verse_id: verse.id).where(approved: [false, nil]))
  end

  # Ayahs that already list this one as similar
  def listed_back_ids
    @listed_back_ids ||= approved_matches.where(matched_verse_id: verse.id).pluck(:verse_id)
  end

  # Matches that score high enough to be listed both ways and aren't yet
  def can_list_both_ways?(match)
    match.score.to_i >= Draft::SimilarAyah::BOTH_WAYS_MIN_SCORE && listed_back_ids.exclude?(match.matched_verse_id)
  end

  def pending_suggestions
    Draft::SimilarAyah.pending_contributions.where(verse_id: verse.id).includes(:user).order(:created_at)
  end

  def page_title
    case action_name
    when 'show'
      "Similar ayahs of #{verse.verse_key}"
    when 'edit', 'update'
      "Suggest a fix: similar ayahs of #{verse.verse_key}"
    else
      'Similar ayahs'
    end
  end

  def meta_title
    page_title
  end

  def meta_description
    'Proofread and suggest fixes for the ayahs that are similar to each ayah of the Quran.'
  end

  private

  def approved_matches
    Morphology::MatchingVerse.approved
  end

  # The matches with their ayahs and words loaded, they're in another database
  def with_verses(scope)
    matches = scope.order(Arel.sql('score DESC NULLS LAST, matched_verse_id')).to_a
    verses = Verse.where(id: matches.map(&:matched_verse_id)).includes(:words).index_by(&:id)
    matches.each { |match| match.matched_verse = verses[match.matched_verse_id] }
  end
end
