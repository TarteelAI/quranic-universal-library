class BaseFinder
  include Pagy::Backend

  attr_reader :locale,
              :per_page,
              :current_page,
              :pagination

  def initialize(locale: nil, current_page: 1, per_page: 20)
    @locale = locale
    @current_page = current_page
    @per_page = per_page
  end

  # Narrows a surah's verse id range down to the requested ayah range. Ayah
  # numbers that don't exist in the surah are ignored rather than blowing up.
  def narrow_to_ayah_range(chapter, first_verse_id, last_verse_id, ayah_range)
    return [first_verse_id, last_verse_id] if ayah_range.blank?

    range_from = Utils::Quran.get_ayah_id(chapter, ayah_range[0])
    range_to = Utils::Quran.get_ayah_id(chapter, ayah_range[1])

    [
      range_from ? [first_verse_id, range_from].max : first_verse_id,
      range_to ? [last_verse_id, range_to].min : last_verse_id
    ]
  end

  def get_ayah_range_to_load(first_verse_id, last_verse_id)
    total_records = records_count(first_verse_id, last_verse_id)

    @pagination = Pagy.new(
      count: total_records,
      page: current_page,
      items: per_page,
      overflow: :empty_page
    )

    if total_records.zero? || @pagination.overflow?
      overflow_range
    else
      offset = first_verse_id - 1
      [offset + @pagination.from, offset + @pagination.to]
    end
  end

  def overflow_range
    [0, 0]
  end

  def records_count(range_start, range_end)
    # An unknown surah leaves the range empty, there is nothing to count then.
    return 0 if range_start.nil? || range_end.nil?

    [(range_end - range_start) + 1, 0].max
  end
end
