# frozen_string_literal: true

require 'json'

module Qiraat
  module Layout
    # Checks a generated layout against the quran-svg ayah polygons (P5.6).
    #
    # quran-svg traces the Complex's own Illustrator pages: per page, one
    # polygon per ayah in reading order, with one rectangular subpath per
    # printed line the ayah touches (pages 1-2 carry a bare point list in
    # their own coordinate space). So for every page the polygons say which
    # ayahs it holds, in which order, and on which lines; the generated
    # mushaf_words say the same, and the two must agree.
    #
    # Lines are read off the polygon's y bands: a band's centre over a
    # 15-line grid fitted to the whole mushaf (pages 3-604 share one text
    # block), and on pages 1-2 by the rank of the band among the page's own
    # line boundaries, counted from the first line after the header lines.
    class SvgDiff
      # quran-text key => quran-svg mushaf folder
      EDITIONS = { 'hafs' => 'hafs', 'shubah' => 'shubah', 'warsh' => 'warsh', 'qalun' => 'qalon', 'duri' => 'douri' }.freeze
      LINES = 15

      attr_reader :key, :report

      def initialize(key:, json_dir:, mushaf:, pages: nil, logger: $stdout)
        @key = key
        @dir = Pathname(json_dir)
        @mushaf = mushaf
        @pages = pages
        @logger = logger
        @report = { edition: key, mushaf_id: mushaf.id, source: @dir.to_s, pages_checked: 0, pages_ok: 0, mismatches: [], skipped_pages: [] }
      end

      def call
        fit_grid
        page_numbers.each { |n| check_page(n) }
        report[:mismatch_pages] = report[:mismatches].map { |m| m[:page] }.uniq
        @logger&.puts("  #{key}: #{report[:pages_ok]}/#{report[:pages_checked]} pages agree with quran-svg, #{report[:mismatches].size} mismatch(es) on #{report[:mismatch_pages].size} page(s)")
        report
      end

      private

      def page_numbers
        @pages || (1..@mushaf.pages_count).to_a
      end

      def page_file(n)
        @dir.join(format('%03d.json', n))
      end

      def polygons(n)
        JSON.parse(page_file(n).read)
      end

      # [[y_top, y_bottom], ...] one per subpath
      def bands(polygon)
        chunks = polygon.strip.start_with?('M') ? polygon.split('M').reject(&:blank?) : [polygon]
        chunks.map do |c|
          ys = c.scan(/-?\d+(?:\.\d+)?/).map(&:to_f).each_slice(2).map(&:last)
          [ys.min, ys.max]
        end
      end

      # The 15-line grid of pages 3+: from the lowest top to the highest
      # bottom over the whole mushaf, so a page whose first line is a header
      # does not shift the grid.
      def fit_grid
        tops = []
        bottoms = []
        page_numbers.select { |n| n >= 3 }.each do |n|
          next unless page_file(n).exist?

          polygons(n).each { |a| bands(a['polygon']).each { |t, b| tops << t; bottoms << b } }
        end
        @top0 = tops.min || 0
        @pitch = ((bottoms.max || LINES) - @top0) / LINES.to_f
      end

      # The lines a band covers: its top and bottom sit on (near) grid lines,
      # and a band may be several lines tall when the ayah fills whole lines.
      def lines_of(band)
        first = ((band[0] - @top0) / @pitch).round + 1
        last = ((band[1] - @top0) / @pitch).round
        last = first if last < first
        (first..last).to_a
      end

      # pages 1-2: the point polygons use their own coordinates, so the
      # page's line boundaries are read off the polygons themselves: every
      # distinct y, clustered (the traced corners of one boundary jitter by
      # up to ~3 units on the Hafs/Shubah pages), ranked top to bottom. The
      # first band is the first text line of the page: the line after the
      # header lines and the basmalah (al-Fatihah opens at line 2 in Hafs,
      # where the basmalah is ayah 1, and at line 3 in Warsh and Duri, where
      # it is an uncounted ayah of its own on line 2).
      OPENING_PAGE_TOLERANCE = 8.0

      def lines_for_opening_page(polys, first_line)
        boundaries = cluster(polys.flat_map { |a| a['polygon'].scan(/-?\d+(?:\.\d+)?/).map(&:to_f).each_slice(2).map(&:last) })
        polys.to_h do |a|
          lines = bands(a['polygon']).flat_map do |t, b|
            (boundary_index(boundaries, t)...boundary_index(boundaries, b)).map { |i| first_line + i }
          end
          ["#{a['surahNumber']}:#{a['ayahNumber']}", lines.uniq.sort]
        end
      end

      # sorted cluster centres of ys, a new cluster when the gap from the
      # cluster's first value exceeds the tolerance
      def cluster(ys)
        ys.sort.slice_when { |a, b| b - a > OPENING_PAGE_TOLERANCE }.map { |c| c.sum / c.size }
      end

      def boundary_index(boundaries, y)
        boundaries.each_with_index.min_by { |b, _| (b - y).abs }.last
      end

      # Lines on the page that carry no words: surah headers and basmalah
      # lines. A polygon of a surah's first ayah may include them.
      def header_lines(n)
        MushafLineAlignment.where(mushaf_id: @mushaf.id, page_number: n, alignment: %w[surah_name bismillah]).pluck(:line_number)
      end

      # surah number => the line of its header on this page. quran-svg gives
      # a surah's first ayah the blank tail of the line before the header as
      # well, so lines above the header are not the ayah's.
      def surah_header_lines(n)
        MushafLineAlignment.where(mushaf_id: @mushaf.id, page_number: n, alignment: 'surah_name').to_h { |a| [a.meta_value('surah-number').to_i, a.line_number] }
      end

      def check_page(n)
        unless page_file(n).exist?
          report[:skipped_pages] << n
          return
        end

        polys = polygons(n)
        rows = MushafWord.where(mushaf_id: @mushaf.id, page_number: n).where.not(ayah_id: nil).order(:position_in_page).pluck(:ayah_id, :line_number)
        keys = NumberedAyah.where(id: rows.map(&:first).uniq).pluck(:id, :ayah_key, :counted).to_h { |id, k, c| [id, [k, c]] }
        gen_lines = Hash.new { |h, k| h[k] = [] }
        gen_order = []
        uncounted_lines = []
        rows.each do |ayah_id, line|
          k, counted = keys[ayah_id]
          unless counted # the uncounted basmalah of al-Fatihah has no polygon
            uncounted_lines << line
            next
          end

          gen_order << k unless gen_order.last == k
          gen_lines[k] << line unless gen_lines[k].include?(line)
        end
        gen_lines.each_value(&:sort!)

        headers = header_lines(n)
        svg_lines = if n <= 2
                      # the first text line follows the header lines and any line holding only the uncounted basmalah
                      blank = headers + (uncounted_lines - gen_lines.values.flatten)
                      lines_for_opening_page(polys, (blank.max || 0) + 1)
                    else
                      polys.to_h { |a| ["#{a['surahNumber']}:#{a['ayahNumber']}", bands(a['polygon']).flat_map { |b| lines_of(b) }.uniq.sort] }
                    end
        svg_lines.transform_values! { |ls| ls - headers } if headers.any?
        surah_header_lines(n).each do |surah, line|
          k = "#{surah}:1"
          svg_lines[k] = svg_lines[k].select { |l| l > line } if svg_lines[k]
        end
        svg_order = polys.map { |a| "#{a['surahNumber']}:#{a['ayahNumber']}" }

        report[:pages_checked] += 1
        page_ok = true
        if svg_order != gen_order
          page_ok = false
          report[:mismatches] << { page: n, kind: 'order', svg: svg_order, generated: gen_order }
        end
        svg_order.each do |k|
          next if svg_lines[k] == gen_lines[k]

          page_ok = false
          report[:mismatches] << { page: n, kind: 'lines', ayah: k, svg: svg_lines[k], generated: gen_lines[k] }
        end
        report[:pages_ok] += 1 if page_ok
      end
    end
  end
end
