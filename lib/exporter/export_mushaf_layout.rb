module Exporter
  class ExportMushafLayout < BaseExporter
    attr_reader :resource_content

    def initialize(resource_content:, base_path:)
      super(base_path: base_path, name: resource_content.sqlite_file_name)
      @resource_content = resource_content
    end

    def export_sqlite
      db_file_path = "#{@export_file_path}.db"

      mushaf = find_mushaf
      page_table_statement = create_sqlite_table(db_file_path, 'pages', pages_table_columns)
      metadata_statement = create_sqlite_table(db_file_path, 'info', metadata_table_columns)

      # export metadata
      metadata_statement.execute([mushaf.name, mushaf.pages_count, mushaf.lines_per_page, mushaf.default_font_name, *riwayah_metadata(mushaf).values])

      # export pages
      pages.each do |page|
        export_page(page, page_table_statement, mushaf)
      end

      close_sqlite_table

      db_file_path
    end

    def export_docs
      require 'docx'
      base_path = "#{@export_file_path}/pages"
      FileUtils.mkdir_p(base_path)

      pages.each do |page|
        export_page_document(page, base_path)
      end

      base_path
    end

    # Exports one JSON file per page (plus an info.json with mushaf metadata) so the
    # layout can be consumed directly without querying the database (issue #257).
    def export_json
      base_path = "#{@export_file_path}/json"
      FileUtils.mkdir_p(base_path)

      mushaf = find_mushaf

      write_json(
        "#{base_path}/info.json",
        {
          name: mushaf.name,
          number_of_pages: mushaf.pages_count,
          lines_per_page: mushaf.lines_per_page,
          font_name: mushaf.default_font_name
        }.merge(riwayah_metadata(mushaf))
      )

      text_method = mushaf.text_type_method
      pages.each do |page|
        export_page_json(page, base_path, mushaf, text_method)
      end

      base_path
    end

    # The mushaf this resource is the layout of (public for the tags of the
    # downloadable resource).
    def mushaf
      find_mushaf
    end

    protected

    # Which reading the layout is for, which ayah counting it prints, and the
    # face it is set in (P5.7). Added to the info row/info.json after the
    # original columns; hand-made Hafs layouts answer hafs/kufi.
    def riwayah_metadata(mushaf)
      script = mushaf.script
      {
        riwayah: mushaf.riwayah&.slug,
        numbering: mushaf.numbering&.slug,
        font_family: script&.font_family.presence || mushaf.default_font_name,
        font_file: script&.font_file_url,
        source_package: mushaf.source_package
      }
    end

    # Shared word numbers and ayah keys (in the mushaf's numbering) at both
    # ends of a line (P5.7). The numbers are quran-text's, so a line of a
    # Warsh layout and a line of a Hafs layout can be aligned word by word;
    # an ayah-end marker carries no number, and a Hafs word standing for two
    # shared words (72:16:1) ends the line on its last number.
    def line_range(rows)
      words = line_words(rows)
      ayahs = rows.map(&:ayah).compact
      {
        first_word_number: words.map(&:number).compact.first,
        last_word_number: words.map { |w| w.number_last || w.number }.compact.last,
        first_ayah: ayahs.first&.ayah_key,
        last_ayah: ayahs.last&.ayah_key
      }
    end

    # The Word rows of a line in reading order. An ayah-end marker of a
    # non-Kufi numbering has no word row (P5.2) and is skipped.
    def line_words(rows)
      rows.map(&:word).compact.sort_by(&:word_index)
    end

    def export_page_document(page, path)
      file = "#{path}/#{page.page_number}.docx"
      doc = Docx::Document.open("#{Rails.root}/lib/exporter/data/template.docx")

      template_lines = doc.paragraphs
      justified_line = template_lines[0]
      centered_aligned_line = template_lines[1]

      page.lines.each do |line|
        last_line = doc.paragraphs.last

        if line[:center_aligned]
          new_line = centered_aligned_line.copy
        else
          new_line = justified_line.copy
        end

        new_line.text = line[:text]
        new_line.insert_after(last_line)
      end

      template_lines.each &:remove!
      doc.save(file)
    end

    def export_page(page, statement, mushaf)
      lines = prepare_page_lines(page, mushaf)

      lines.keys.sort.each_with_index do |line, index|
        range_start = range_end = nil
        alignment, line_type = get_line_alignment(page, line, mushaf)

        rows = lines[line] || []
        if line_type == 'ayah' && rows.present?
          words = line_words(rows)

          range_start = words.first&.word_index
          range_end = words.last&.word_index
        elsif line_type == 'surah_name'
          range_start = alignment.get_surah_number
        end

        is_centered = alignment&.is_center_aligned? || line_type == 'surah_name' || line_type == 'basmallah'

        fields = [
          page.page_number,
          index + 1, # line number
          line_type,
          is_centered ? 1 : 0
        ]

        if line_type == 'ayah'
          fields << range_start
          fields << range_end
          fields << ''
        elsif line_type == 'surah_name'
          fields << ''
          fields << ''
          fields << range_start
        else
          fields << ''
          fields << ''
          fields << ''
        end
        fields += line_type == 'ayah' ? line_range(rows).values : [nil, nil, nil, nil]

        statement.execute(fields)
      end
    end

    def export_page_json(page, path, mushaf, text_method)
      lines = prepare_page_lines(page, mushaf)
      page_data = { page: page.page_number, lines: {} }

      lines.keys.sort.each_with_index do |line, index|
        alignment, line_type = get_line_alignment(page, line, mushaf)
        is_centered = alignment&.is_center_aligned? || line_type == 'surah_name' || line_type == 'basmallah'

        line_data = {
          type: line_type,
          alignment: is_centered ? 'centered' : 'justified'
        }

        case line_type
        when 'ayah'
          rows = lines[line] || []
          words = line_words(rows)
          line_data[:first_word_id] = words.first&.word_index
          line_data[:last_word_id] = words.last&.word_index
          line_data[:data] = words.map { |word| word.send(text_method) }
          line_data.merge!(line_range(rows))
        when 'surah_name'
          line_data[:surah_number] = alignment&.get_surah_number
        end

        page_data[:lines][index + 1] = line_data
      end

      write_json("#{path}/#{page.page_number}.json", page_data)
    end

    def prepare_page_lines(page, mushaf)
      lines = {}
      page_alignment = MushafLineAlignment
                         .where(
                           mushaf_id: mushaf.id,
                           page_number: page.page_number
                         )
                         .order('line_number ASC')

      page_alignment.each do |alignment|
        lines[alignment.line_number.to_i] ||= []
      end

      # mushaf_words rows (the Word may be nil on an ayah-end marker of a non-Kufi numbering)
      page.words.includes(:word, :ayah).order('position_in_page ASC').each do |w|
        lines[w.line_number] ||= []
        lines[w.line_number].push(w)
      end

      lines
    end

    def get_line_alignment(page, line, mushaf)
      alignment = MushafLineAlignment.where(
        mushaf_id: mushaf.id,
        page_number: page.page_number,
        line_number: line
      ).first

      line_type = if alignment
                    if alignment.is_surah_name?
                      'surah_name'
                    elsif alignment.is_bismillah?
                      'basmallah'
                    else
                      'ayah'
                    end
                  else
                    'ayah'
                  end

      [alignment, line_type]
    end

    def pages
      MushafPage.where(mushaf_id: find_mushaf.id).order('page_number ASC')
    end

    def find_mushaf
      return @mushaf if defined?(@mushaf)

      # the resource's own mushaf first: a layout slug is not unique, and a
      # generated layout may once have pointed at a hand-made one's resource
      candidates = Mushaf.where(resource_content_id: resource_content.id).order(:id)
      @mushaf = candidates.find_by(id: resource_content.resource_id) if resource_content.resource_type == 'Mushaf'
      @mushaf ||= candidates.first || resource_content.resource
      @mushaf
    end

    def pages_table_columns
      {
        page_number: 'INTEGER',
        line_number: 'INTEGER',
        line_type: 'TEXT',
        is_centered: 'INTEGER',
        first_word_id: 'INTEGER',
        last_word_id: 'INTEGER',
        surah_number: 'INTEGER',
        # P5.7, after the original columns: shared word numbers and ayah keys in the mushaf's numbering
        first_word_number: 'INTEGER',
        last_word_number: 'INTEGER',
        first_ayah: 'TEXT',
        last_ayah: 'TEXT'
      }
    end

    def metadata_table_columns
      {
        name: 'TEXT',
        number_of_pages: 'INTEGER',
        lines_per_page: 'INTEGER',
        font_name: 'TEXT',
        # P5.7
        riwayah: 'TEXT',
        numbering: 'TEXT',
        font_family: 'TEXT',
        font_file: 'TEXT',
        source_package: 'TEXT'
      }
    end
  end
end
