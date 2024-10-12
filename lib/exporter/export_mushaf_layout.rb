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
      metadata_statement.execute([mushaf.name, mushaf.pages_count, mushaf.lines_per_page, mushaf.default_font_name])

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

    protected

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

        if line_type == 'ayah' && lines[line].present?
          words = lines[line].sort_by { |word| word.word_index }

          range_start = words.first.word_index
          range_end = words.last.word_index
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

        statement.execute(fields)
      end
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

      page.words.includes(:word).order('position_in_page ASC').each do |w|
        lines[w.line_number] ||= []
        lines[w.line_number].push(w.word)
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

      @mushaf = Mushaf.find_by(resource_content_id: resource_content.id)
      @mushaf ||= resource_content.resource
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
      }
    end

    def metadata_table_columns
      {
        name: 'TEXT',
        number_of_pages: 'INTEGER',
        lines_per_page: 'INTEGER',
        font_name: 'TEXT'
      }
    end
  end
end
