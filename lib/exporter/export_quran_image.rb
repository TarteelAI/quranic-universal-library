module Exporter
  class ExportQuranImage < BaseExporter
    def initialize(resource_content:, base_path:)
      super(base_path: base_path, name: resource_content.sqlite_file_name)
      @resource_content = resource_content
    end

    def export_wbw
    end

    def export_ayah_by_ayah
    end

    def export_page_by_page
    end

    protected
  end
end