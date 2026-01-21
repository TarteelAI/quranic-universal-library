class ExportAssetsManifest
  attr_reader :manifest_version,
              :min_app_version,
              :base_path

  def initialize(manifest_version: 1, min_app_version: nil, base_path: 'tmp/export')
    @manifest_version = manifest_version
    @min_app_version = min_app_version
    @base_path = base_path

    FileUtils.mkdir_p(@base_path)
  end

  def export
    manifest = build_manifest
    file_path = File.join(base_path, "assets-manifest-#{manifest_version}.json")

    File.open(file_path, 'w') do |f|
      f << JSON.pretty_generate(manifest)
    end

    file_path
  end

  protected

  def build_manifest
    {
      manifest_version: manifest_version,
      generated_at: Time.current.iso8601,
      min_app_version: min_app_version,
      assets: {
        translations: build_translations_assets,
        tafsirs: build_tafsirs_assets,
        segments: build_audio_segments_assets,
        audio: build_audio_assets
      }
    }
  end

  def build_translations_assets
    resources = ResourceContent
                  .translations
                  .approved
                  .joins(:resource_tags)
                  .where(resource_tags: { tag_id: tag.id })

    build_assets_map(resources, resource_type: 'translation')
  end

  def build_tafsirs_assets
    resources = ResourceContent
                  .tafsirs
                  .approved
                  .joins(:resource_tags)
                  .where(resource_tags: { tag_id: tag.id })

    build_assets_map(resources, resource_type: 'tafsir')
  end

  def build_audio_assets
    resources = ResourceContent
                  .recitations
                  .one_chapter
                  .joins(:resource_tags)
                  .where(resource_tags: { tag_id: tag.id })

    build_assets_map(resources, resource_type: 'audio')
  end

  def build_audio_segments_assets
    resources = ResourceContent
                  .recitations
                  .one_chapter
                  .joins(:resource_tags)
                  .where(resource_tags: { tag_id: tag.id })

    build_assets_map(resources, resource_type: 'segments')
  end

  def tag
    Tag.where(name: 'Tarteel').first
  end

  def build_assets_map(resources, resource_type:)
    assets = []

    resources.find_each do |resource|
      assets << build_asset_entry(resource, resource_type: resource_type)
    end

    assets
  end

  def build_asset_entry(resource, resource_type:)
    {
      id: resource.id,
      version: resource.meta_value('exported-version').to_i,
      key: resource.meta_value('exported-tag'),
      size_bytes: resource.meta_value('exported-file-size-bytes'),
      url: build_cdn_url(resource, resource_type: resource_type),
      update_policy: 'auto',
    }
  end

  def build_cdn_url(resource, resource_type:)
    case resource_type
    when 'translation', 'tafsir'
      version = resource.meta_value('exported-version').to_i
      name = resource.meta_value('exported-tag')

      "#{content_cnd_host}/translations/#{name}-#{version}.json"
    when 'audio'
      name = resource.meta_value('audio-path')

      "#{audio_cdn_host}/#{name}"
    when 'segments'
      name = resource.meta_value('segments-path')
      "#{audio_cdn_host}/segments/gapless/#{name}.json"
    else
      raise "Unknown resource type: #{resource_type}"
    end
  end

  def content_cnd_host
    ENV['CND_HOST']
  end

  def audio_cdn_host
    ENV['AUDIO_CND_HOST']
  end
end
