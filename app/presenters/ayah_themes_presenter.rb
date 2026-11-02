class AyahThemesPresenter < ApplicationPresenter
  def themes
    list = AyahTheme.includes(:chapter)
    list = list.where(chapter_id: params[:filter_chapter].to_i) if params[:filter_chapter].present?

    if filtered_verse
      list = list.where(':id BETWEEN verse_id_from AND verse_id_to', id: filtered_verse.id)
    end

    if params[:query].present?
      query = "%#{ActiveRecord::Base.sanitize_sql_like(params[:query].strip)}%"
      list = list.where('theme ILIKE :query OR keywords::text ILIKE :query', query: query)
    end

    paginate(list.order(:chapter_id, :verse_id_from))
  end

  def filtered_verse
    return @filtered_verse if defined?(@filtered_verse)

    @filtered_verse = if params[:filter_chapter].present? && params[:verse_number].present?
                        Verse.find_by(chapter_id: params[:filter_chapter].to_i, verse_number: params[:verse_number].to_i)
                      end
  end

  def theme
    @theme ||= AyahTheme.find(params[:id])
  end

  def previous_theme
    AyahTheme.where('verse_id_to < ?', theme.verse_id_from).order(verse_id_to: :desc).first
  end

  def next_theme
    AyahTheme.where('verse_id_from > ?', theme.verse_id_to).order(:verse_id_from).first
  end

  # The themes just before and after it in the surah, a new range can shorten them
  def neighbour_themes(count = 3)
    surah = AyahTheme.where(chapter_id: theme.chapter_id)
    before = surah.where('verse_id_to < ?', theme.verse_id_from).order(verse_id_from: :desc).limit(count).to_a.reverse
    after = surah.where('verse_id_from > ?', theme.verse_id_to).order(:verse_id_from).limit(count).to_a

    [before, after]
  end

  def pending_suggestions
    Draft::AyahTheme.pending_contributions.where(ayah_theme_id: theme.id).includes(:user).order(:created_at)
  end

  def page_title
    case action_name
    when 'show'
      "Theme of #{theme.chapter.name_simple} #{theme.range_label}"
    when 'edit', 'update'
      "Suggest a fix: theme of #{theme.range_label}"
    else
      'Ayah themes'
    end
  end

  def meta_title
    page_title
  end

  def meta_description
    'Proofread and suggest fixes for the theme of each group of ayahs.'
  end
end
