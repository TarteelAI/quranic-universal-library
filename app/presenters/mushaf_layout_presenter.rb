class MushafLayoutPresenter < ApplicationPresenter
  attr_reader :mushaf, :compared_mushaf, :resource

  def mushaf
    @mushaf ||= load_mushaf!
  end

  def resource
    @resource ||= load_resource!
  end

  def compared_mushaf
    @compared_mushaf ||= load_compared_mushaf!
  end

  def mushaf_page
    @mushaf_page ||= load_mushaf_page!
  end

  def compare_mushaf_page
    @compare_mushaf_page ||= load_compare_mushaf_page!
  end

  def reload_mushaf_page!
    @mushaf_page = load_mushaf_page!
  end

  def load_mushaf!
     Mushaf.find(params[:id]) if params[:id].present?
  end

  def load_resource!
    mushaf&.resource_content
  end

  def load_compared_mushaf!
     Mushaf.find(params[:compare]) if params[:compare].present?
  end

  def load_mushaf_page!
    return if mushaf.blank?

     MushafPage.where(
       mushaf_id: mushaf.id,
       page_number: page_number
     ).first_or_initialize
  end

  def load_compare_mushaf_page!
     MushafPage.where(mushaf_id: compared_mushaf.id, page_number: page_number).first if compared_mushaf
  end

  def mushafs
    @mushafs ||= Mushaf.order("#{sort_key} #{sort_order}")
  end

  def mushaf_pages
    @pages ||= begin
      pages = load_sorted_pages
      pages = apply_search_filter(pages) if search_term.present?
      pages
    end
  end

  def pages_with_status
    calculate_page_statuses
    mushaf_pages
  end

  def words_count_for_page(page_number)
    @words_counts ||= {}
    @words_counts[page_number] || 0
  end

  def lines_count_for_page(page_number)
    @lines_counts ||= {}
    @lines_counts[page_number] || 0
  end

  # Edit action methods
  def verses
    @verses ||= load_verses_for_page
  end

  def words
    @words ||= load_page_words
  end

  def compared_words
    @compared_words ||= load_compared_words if compared_mushaf
  end

  def lines_per_page
    @lines_per_page ||= resource&.resource&.lines_per_page
  end

  def ayah_range_missing?
    mushaf_page&.first_verse_id.nil? || mushaf_page&.last_verse_id.nil?
  end

  # Page metadata
  def page_title
    case action_name
    when 'index'
      "Mushaf Layouts"
    when 'show'
      "#{resource&.name || 'Mushaf'} - Page #{page_number}"
    when 'edit'
      "Update #{resource&.name || 'Mushaf'} - Page #{page_number}"
    end
  end

  def meta_title
    case action_name
    when 'index'
      "Mushaf Layouts"
    when 'show'
      "#{resource&.name || 'Mushaf'} Layout - Page #{page_number}"
    when 'edit'
      "Edit #{resource&.name || 'Mushaf'} Layout - Page #{page_number}"
    end
  end

  def meta_description
    case action_name
    when 'index'
      "Customize Quran Mushaf page layouts. Adjust lines per page, align verses, map page ranges."
    else
      "Edit layout for #{resource&.name || 'Mushaf'} Mushaf page #{page_number}. Adjust word placement and line alignment."
    end
  end

  def meta_keywords
    case action_name
    when 'index'
      "Mushaf layout, Quran page layout, line alignment, page mapping"
    else
      "Mushaf layout, #{resource&.name || 'Mushaf'}, page #{page_number}, word placement, line alignment"
    end
  end

  private

  def load_verses_for_page
    return nil unless mushaf_page
    
    first_verse = mushaf_page.first_verse
    last_verse = mushaf_page.last_verse

    return nil unless first_verse && last_verse

    Verse.eager_load(:words)
         .order("verses.verse_index asc, words.position asc")
         .where("verse_index >= ? AND verse_index <= ?", first_verse.verse_index, last_verse.verse_index)
  end

  def load_page_words
    return [] unless mushaf && resource

    MushafWord.where(
      mushaf_id: resource.resource_id,
      page_number: page_number
    ).order('position_in_page ASC')
  end

  def load_compared_words
    return [] unless compared_mushaf

    MushafWord.where(
      mushaf_id: compared_mushaf.id,
      page_number: page_number
    ).order('position_in_page ASC')
  end

  def load_sorted_pages
    return [] unless mushaf

    sort_key_param = params[:sort_key] || 'page_number'
    sort_order_param = params[:sort_order] || 'asc'

    allowed_sort_keys = ['page_number', 'first_verse_id', 'last_verse_id', 'verses_count', 'lines_count']
    sort_key_param = 'page_number' unless allowed_sort_keys.include?(sort_key_param)
    sort_order_param = 'asc' unless ['asc', 'desc'].include?(sort_order_param)

    mushaf.mushaf_pages.preload(:first_verse, :last_verse).order("#{sort_key_param} #{sort_order_param}")
  end

  def apply_search_filter(pages)
    return pages if search_term.blank?
    
    if search_term.match?(/^\d+$/)
      return pages.where(page_number: search_term.to_i)
    end
    
    if search_term.include?(':')
      parts = search_term.split(':')
      if parts.length == 2
        surah = parts[0].to_i
        ayah = parts[1].to_i
        
        if surah > 0 && ayah > 0
          verse = Verse.find_by(chapter_id: surah, verse_number: ayah)
          if verse
            return pages.where("(first_verse_id <= ? AND last_verse_id >= ?)", verse.id, verse.id)
          end
        end
      end
    end
    
    pages
  end

  def calculate_page_statuses
    page_numbers = mushaf_pages.pluck(:page_number)
    
    @words_counts = MushafWord.where(mushaf_id: mushaf.id, page_number: page_numbers)
                              .group(:page_number)
                              .count
    
    @lines_counts = MushafWord.where(mushaf_id: mushaf.id, page_number: page_numbers)
                              .where.not(line_number: [0, nil])
                              .group(:page_number)
                              .count
  end

  def search_term
    @search_term ||= params[:search].to_s.strip
  end

  def sort_key
    sortby = params[:sort_key].presence || 'id'

    if ['id', 'name', 'lines_per_page', 'pages_count'].include?(sortby)
      sortby
    else
      'id'
    end
  end

  def sort_order
    params[:sort_order] || 'asc'
  end
end