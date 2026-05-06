class TranslationDiffPresenter < ApplicationPresenter
  def exported_translations
    tag = Tag.find(5)
    ids = tag
            .resource_tags
            .where(resource_type: 'ResourceContent')
            .select(:resource_id)

    ResourceContent
      .where(id: ids)
      .order(:name)
  end

  def current_translations
    Translation
      .where(resource_content_id: resource.id)
      .includes(:verse)
      .order('verse_id ASC')
  end

  def diffs
    @diffs ||= build_diffs
  end

  def exported_version(translation = nil)
    if translation
      translation.meta_value('exported-version').to_i
    else
      (params[:version] || resource.meta_value('exported-version')).to_i
    end
  end

  def resource
    @resource ||= ResourceContent.find(params[:id])
  end

  def translation_key(translation)
    ExportService::TRANSLATION_NAME_MAPPING[translation.id]
  end

  protected

  def build_diffs
    loaded = load_exported_translations
    exporter = Exporter::AyahTranslation.new

    current_translations.filter_map do |translation|
      current = exporter.export_chunks(translation)
      current.delete(:f) if current[:f].blank?
      exported = get_ayah_translation(loaded, translation.verse_key)

      current_str, exported_str = stringify(current, exported)
      diff = Diffy::Diff.new(exported_str, current_str).to_s(:html).html_safe

      next unless diff.include?('<li')

      { translation: translation, exported: exported_str, current: current_str, diff: diff }
    end
  end

  def stringify(current, exported)
    if exported.is_a?(String)
      [current[:t].join(''), exported.to_s]
    else
      [current.to_json, exported.to_json]
    end
  end

  def get_ayah_translation(data, verse_key)
    if data.is_a?(Array)
      s, a = verse_key.split(':').map(&:to_i)
      data[s - 1][a - 1]
    else
      data[verse_key]
    end
  end

  def load_exported_translations
    cache_key = "translation_diff/#{resource.id}/v#{exported_version}"
    Rails.cache.fetch(cache_key, expires_in: 10.minutes) do
      fetch_from_cdn
    end
  end

  def fetch_from_cdn
    cdn_url = ENV['TRANSLATION_CDN_URL']
    key = ExportService.new(resource).get_export_file_name
    url = "#{cdn_url}/#{key}-#{exported_version}.json?d=d"

    uri = URI(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 30

    Oj.safe_load(http.get(uri.request_uri).body)
  end
end
