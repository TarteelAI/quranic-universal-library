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

  def get_ayah_range_to_load(first_verse_id, last_verse_id)
    total_records = records_count(first_verse_id, last_verse_id)

    @pagination = Pagy.new(
      count: total_records,
      page: current_page,
      items: per_page,
      overflow: :empty_page
    )

    if @pagination.overflow?
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
    (range_end - range_start) + 1
  end
end