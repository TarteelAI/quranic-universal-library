module Exporter
  class ExportTafsir < BaseExporter
    attr_accessor :resource_content

    def initialize(resource_content:, base_path:)
      super(base_path: base_path, name: resource_content.sqlite_file_name)
      @resource_content = resource_content
    end

    def export_json
      json_file_path = "#{export_file_path}.json"
      export_data

      File.open(json_file_path, 'wb') do |file|
        file << JSON.generate(@json_data, { state: JsonNoEscapeHtmlState.new })
      end

      json_file_path
    end

    def export_sqlite
      export_data

      db_file_path = "#{@export_file_path}.db"
      statement = create_sqlite_table(db_file_path, 'tafsir', sqlite_db_columns)

      @json_data.each do |verse_key, data|
        fields = [verse_key]

        if data.is_a?(String)
          group_ayah_key = data
          fields += [group_ayah_key, '', '', '', '']
        else
          group_keys = data[:ayah_keys] || [verse_key]
          fields += [verse_key, group_keys.first, group_keys.last, group_keys.join(','), data[:text]]
        end

        statement.execute(fields)
      end
      close_sqlite_table

      db_file_path
    end

    protected
    def export_data
      return @json_data if @json_data.present?

      @json_data = {}

      Verse.order('verse_index ASC').find_each do |verse|
        if @json_data[verse.verse_key].present?
          next
        end

        @json_data[verse.verse_key] = {}
        tafsir = Tafsir.where(archived: false).for_verse(verse, resource_content)

        if (tafsir)
          group = tafsir.ayah_group_list
          first_ayah = group.first

          @json_data[first_ayah] = {
            text: tafsir.text.to_s.strip
          }

          if group.length > 1
            @json_data[first_ayah][:ayah_keys] = group

            group.each do |key|
              @json_data[key] = first_ayah if @json_data[key].blank?
            end
          end
        end
      end

      @json_data
    end


    def format_text(text)
      # NOTE: we need to fix the source data to have proper html tags
      # TODO: remove this method once the source data is fixed

      doc = Nokogiri::HTML::DocumentFragment.parse(text)
      doc.css('h3').each do |h3|
        h3.name = 'div'
      end

      doc.to_html

      text
    end

    def sqlite_db_columns
      {
        ayah_key: 'TEXT',
        group_ayah_key: 'TEXT',
        from_ayah: 'TEXT',
        to_ayah: 'TEXT',
        ayah_keys: 'TEXT',
        text: 'TEXT',
      }
    end
  end
end