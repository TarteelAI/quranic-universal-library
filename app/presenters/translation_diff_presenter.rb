class TranslationDiffPresenter < ApplicationPresenter
  attr_reader :exported_translations

  def exported_translations
    ResourceContent.where(id: ExportService::TRANSLATION_NAME_MAPPING.keys)
  end

  def current_translations
    records = Translation
                .where(resource_content_id: resource.id)
                .order('verse_id ASC')

    if params[:chapter]
      records = records.where(chapter_id: params[:chapter])
    end

    records
  end

  def generate_diff(translation)
    @exported_translations ||= load_exported_translations
    export_service ||= Exporter::AyahTranslation.new

    current_translation = export_service.export_chunks(translation)
    current_translation.delete(:f) if current_translation[:f].blank?

    exported_translation = get_ayah_translation(@exported_translations, translation.verse_key)

    if exported_translation.is_a?(String)
      current_translation = "#{current_translation[:t].join('')}"
    else
      current_translation = current_translation.to_json
      exported_translation = exported_translation.to_json
    end

    diff = Diffy::Diff.new(exported_translation.to_s, current_translation.to_s).to_s(:html).html_safe

    [exported_translation, current_translation, diff]
  end

  def exported_version(translation = nil)
    if translation
      translation.meta_value('exported-version').to_i
    else
      (params[:version] || resource.meta_value('exported-version')).to_i
    end
  end

  def resource
    ResourceContent.find(params[:id])
  end

  def translation_key(translation)
    ExportService::TRANSLATION_NAME_MAPPING[translation.id]
  end

  protected

  def get_ayah_translation(data, verse_key)
    if data.is_a?(Array)
      s, a = verse_key.split(':').map(&:to_i)
      data[s.to_i - 1][a.to_i - 1]
    else
      data[verse_key]
    end
  end

  def load_exported_translations
    key = ExportService.new(resource).get_export_file_name
    url = "#{ENV['TRANSLATION_CDN_URL']}/#{key}-#{exported_version}.json"

    uri = URI(url)
    Net::HTTP.version_1_2 # make sure we use higher HTTP protocol version than 1.0
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    Oj.safe_load(http.get(url).body)
  end
end