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
    file_path = File.join(base_path, "manifest-#{manifest_version}.json")

    File.open(file_path, 'w') do |f|
      f << JSON.pretty_generate(manifest)
    end

    file_path
  end

  def upload(manifest_path: nil)
    manifest_path ||= export
    object_key = "asset-manifests/#{File.basename(manifest_path)}"

    uploader = UploadToCdn.new
    uploader.upload(manifest_path, object_key)
  end

  def export_and_upload
    manifest_path = export
    upload(manifest_path: manifest_path)
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
    entry = {
      id: resource.id,
      version: asset_version(resource, resource_type),
      key: resource.meta_value('exported-tag'),
      size_bytes: asset_size(resource, resource_type),
      url: build_cdn_url(resource, resource_type: resource_type),
      update_policy: 'auto',
    }

    entry[:duration_ms] = audio_totals(resource)[:duration_ms].to_i if resource_type == 'audio'
    entry
  end

  # Totals of a reciter's surah mp3s, from the probed metadata on each file, so
  # re-exporting the manifest picks up any audio change.
  def audio_totals(resource)
    audio_totals_by_resource[resource.id] || {}
  end

  def audio_totals_by_resource
    @audio_totals_by_resource ||= Audio::ChapterAudioFile
                                    .joins(:audio_recitation)
                                    .where(chapter_id: 1..114)
                                    .group('audio_recitations.resource_content_id')
                                    .pluck(
                                      'audio_recitations.resource_content_id',
                                      Arel.sql('SUM(audio_chapter_audio_files.file_size)'),
                                      Arel.sql('SUM(audio_chapter_audio_files.duration_ms)')
                                    )
                                    .to_h do |resource_id, size, duration|
                                      [resource_id, { size_bytes: size, duration_ms: duration }]
                                    end
  end

  # Audio and segments are two separate files on the CDN, so they carry two
  # separate versions - a segment fix must not invalidate the mp3s.
  def asset_version(resource, resource_type)
    case resource_type
    when 'audio', 'segments'
      resource.exported_asset_version(resource_type)
    else
      resource.meta_value('exported-version').to_i
    end
  end

  # The size of the content the client downloads: every mp3 for audio, not the
  # audio_files.json that lists them.
  def asset_size(resource, resource_type)
    case resource_type
    when 'audio'
      audio_totals(resource)[:size_bytes].to_i
    when 'segments'
      resource.exported_asset_size(resource_type)
    else
      resource.meta_value('exported-file-size-bytes')
    end
  end

  def build_cdn_url(resource, resource_type:)
    case resource_type
    when 'translation', 'tafsir'
      version = resource.meta_value('exported-version').to_i
      name = resource.meta_value('exported-tag')

      "#{content_cnd_host}/translations/#{name}-#{version}.json"
    when 'audio'
      "#{content_cnd_host}/audio/gapless/#{resource.id}/audio_files.json"
    when 'segments'
      "#{content_cnd_host}/audio/gapless/#{resource.id}/segments.json"
    else
      raise "Unknown resource type: #{resource_type}"
    end
  end

  def content_cnd_host
    ENV['CDN_HOST']
  end
end
