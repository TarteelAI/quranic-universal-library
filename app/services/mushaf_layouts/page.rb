# frozen_string_literal: true

module MushafLayouts
  # One page of a mushaf layout: its lines in order, each with its alignment and its words.
  #
  # Words come from the content database and line alignments from the CMS database, so they are
  # loaded in two queries. A line without an alignment row is justified. One line can hold a
  # surah name and a bismillah together (the 16-line IndoPak layout does).
  class Page
    Line = Struct.new(:number, :centered, :surah_number, :bismillah, :words, keyword_init: true)

    attr_reader :mushaf, :number

    # The mushaf behind a layout resource. The `mushaf` meta key wins; otherwise the content row
    # can map to more than one mushaf, so the enabled one with the lowest id is taken.
    def self.mushaf_for(resource)
      mushafs_for([resource])[resource.id]
    end

    # The same lookup for many layouts in two queries: resource id => mushaf (or nil).
    def self.mushafs_for(resources)
      contents = resources.filter_map(&:resource_content)
      by_id = Mushaf.where(id: contents.filter_map { |content| content.meta_value('mushaf').presence })
                    .index_by { |mushaf| mushaf.id.to_s }
      by_content = Mushaf.where(resource_content_id: contents.map(&:id)).order(enabled: :desc, id: :asc)
                         .group_by(&:resource_content_id)

      resources.to_h do |resource|
        content = resource.resource_content
        [resource.id, content && (by_id[content.meta_value('mushaf').to_s] || by_content[content.id]&.first)]
      end
    end

    # Pages outside 1..pages_count are clamped: one mushaf has more page rows than pages.
    def initialize(mushaf, number)
      @mushaf = mushaf
      @number = number.to_i.clamp(1, mushaf.pages_count)
    end

    def lines
      words = page_words.group_by(&:line_number)
      alignments = MushafLineAlignment.where(mushaf_id: mushaf.id, page_number: number).index_by(&:line_number)

      (1..mushaf.lines_per_page).filter_map do |line_number|
        alignment = alignments[line_number]
        next if alignment.nil? && !words.key?(line_number)

        Line.new(
          number: line_number,
          centered: alignment.present? && (alignment.is_center_aligned? || alignment.is_bismillah?),
          surah_number: alignment&.get_surah_number&.to_i,
          bismillah: alignment.present? && alignment.is_bismillah?,
          words: in_verse_order(words.fetch(line_number, []))
        )
      end
    end

    private

    # mushaf_words has no index on (mushaf_id, page_number); Postgres reads the mushaf's rows
    # through the (mushaf_id, word_id) index and filters on the page (about 10 ms per page).
    # Word order is position_in_page: position_in_line is wrong for many lines' first word.
    def page_words
      MushafWord
        .where(mushaf_id: mushaf.id, page_number: number)
        .order(:position_in_page)
        .select(:id, :text, :char_type_name, :line_number, :verse_id)
        .to_a
    end

    # Keeps each verse's words together, verses in the order they start on the line, as the old
    # preview does. A few marks sit after the next verse's first word in position_in_page.
    def in_verse_order(words)
      words.group_by(&:verse_id).values.flatten
    end
  end
end
