module Exporter
  class ExportFont < BaseExporter
    attr_reader :font_version
    def initialize(resource_content:, base_path:)
      super(
        base_path: base_path,
        resource_content: resource_content
      )

      @font_version = 'v1.0.0'
    end

    def export_ttf
      font_file_path = resource_content.meta_value('ttf')
      font_path = resource_content.meta_value('font_path')
      base_path = "#{@base_path}/#{font_path}/ttf"
      FileUtils.mkdir_p(base_path)

      if font_path.present?
        if resource_content.page?
          1.upto(604) do |page|
            download_font("#{font_file_path}/p#{page}.ttf", "#{base_path}/p#{page}.ttf")
          end

          base_path
        else
          export_path = "#{base_path}/#{font_file_path}.ttf"
          download_font("#{font_file_path}.ttf", export_path)

          export_path
        end
      end
    end

    def export_woff
      font_file_path = resource_content.meta_value('woff')
      font_path = resource_content.meta_value('font_path')
      base_path = "#{@base_path}/#{font_path}/woff"
      FileUtils.mkdir_p(base_path)

      if font_path.present?
        if resource_content.page?
          1.upto(604) do |page|
            download_font("#{font_file_path}/p#{page}.woff", "#{base_path}/p#{page}.woff")
          end

          base_path
        else
          export_path = "#{base_path}/#{font_file_path}.woff"
          download_font("#{font_file_path}.woff", export_path)

          export_path
        end
      end
    end

    def export_woff2
      font_file_path = resource_content.meta_value('woff2')
      font_path = resource_content.meta_value('font_path')
      base_path = "#{@base_path}/#{font_path}/woff2"
      FileUtils.mkdir_p(base_path)

      if font_path.present?
        if resource_content.page?
          1.upto(604) do |page|
            download_font("#{font_file_path}/p#{page}.woff2", "#{base_path}/p#{page}.woff2")
          end

          base_path
        else
          export_path = "#{base_path}/#{font_file_path}.woff2"
          download_font("#{font_file_path}.woff2", export_path)

          export_path
        end
      end
    end

    def export_svg
      font_file_path = resource_content.meta_value('svg')
      font_path = resource_content.meta_value('font_path')
      base_path = "#{@base_path}/#{font_path}/svg"
      FileUtils.mkdir_p(base_path)

      if font_path.present?
        if resource_content.page?
          1.upto(604) do |page|
            download_font("#{font_file_path}/p#{page}.svg", "#{base_path}/p#{page}.svg")
          end

          base_path
        else
          export_path = "#{base_path}/#{font_file_path}.svg"
          download_font("#{font_file_path}.svg", export_path)

          export_path
        end
      end
    end

    def export_otf
      font_file_path = resource_content.meta_value('otf')
      font_path = resource_content.meta_value('font_path')
      base_path = "#{@base_path}/#{font_path}/otf"
      FileUtils.mkdir_p(base_path)

      if font_path.present?
        if resource_content.page?
          1.upto(604) do |page|
            download_font("#{font_file_path}/p#{page}.otf", "#{base_path}/p#{page}.otf")
          end

          base_path
        else
          export_path = "#{base_path}/#{font_file_path}.otf"
          download_font("#{font_file_path}.otf", export_path)

          export_path
        end
      end
    end

    def export_ligatures
      ligatures = resource_content.meta_value('ligatures')

      if ligatures.present?
        font_path = resource_content.meta_value('font_path')
        base_path = "#{@base_path}/#{font_path}"

        FileUtils.mkdir_p(base_path)
        ligatures_data = Oj.load(ligatures) rescue ligatures
        write_json("#{base_path}/ligatures.json", ligatures_data)

        "#{base_path}/ligatures.json"
      end
    end

    protected

    def download_font(src_path, destination_path)
      return if File.exist?(destination_path)

      src_path = "https://static-cdn.tarteel.ai/qul/fonts/#{src_path}?v=#{font_version}"
      Utils::Downloader.download(src_path, destination_path)
    end
  end
end