# frozen_string_literal: true

module Catalog
  # One published resource of each type whose card on the home page shows a part of its preview,
  # chosen from the resource's own fields rather than by id: a recommended resource first, then a
  # stable one before a beta one, then (recitations) one whose Al-Fatihah has segment data, so the
  # card highlights each ayah, then the most downloaded (as the catalog's popular sort counts it),
  # then by name. Legacy and superseded resources are never shown. A type with no such resource is
  # left out.
  class Samples
    # Type => what a sample of that type must be. A recitation is surah by surah, so the preview
    # plays one file with each ayah timed; a translation is ayah by ayah.
    TYPES = {
      'recitation' => { cardinality_type: '1_chapter' },
      'mushaf-layout' => {},
      'quran-script' => { cardinality_type: '1_ayah' },
      'translation' => { cardinality_type: '1_ayah' },
      'tafsir' => {},
      'morphology' => {},
      'ayah-topics' => {},
      'quran-metadata' => { cardinality_type: '1_chapter' },
    }.freeze
    STATUSES = ['stable', 'beta'].freeze
    # The scripts the script card shows side by side, by the text type their meta names.
    SCRIPTS = { 'text_qpc_hafs' => 'Madani', 'text_digital_khatt_indopak' => 'IndoPak' }.freeze
    # The script card's last line is a font that draws the surah names: one file for the surahs.
    SURAH_NAMES = 'Surah names'
    SURAH_NAME_FONT = { resource_type: 'font', cardinality_type: '1_chapter' }.freeze
    SURAH_NAME = /\Asurah names?\b/i

    # Type => DownloadableResource.
    def call
      scopes = TYPES.map { |type, conditions| DownloadableResource.published.where(resource_type: type, **conditions) }
      candidates = scopes.reduce(:or).select { |resource| STATUSES.include?(resource.status) }
      downloads = downloads(candidates)
      timed = timed(candidates)

      candidates.group_by(&:resource_type).transform_values do |resources|
        resources.min_by { |resource| rank(resource, timed, downloads) }
      end.slice(*TYPES.keys)
    end

    # [label, resource] for each of SCRIPTS that has a published ayah-by-ayah script, then for a
    # surah name font: the first of each as `call` ranks them, downloads aside.
    def scripts
      by_text_type = script_candidates.group_by { |resource| resource.resource_content&.meta_value('text-type') }
      scripts = SCRIPTS.filter_map do |text_type, label|
        by_text_type[text_type]&.min_by { rank(_1, Set.new, {}) }&.then { [label, _1] }
      end
      scripts + [surah_name_font&.then { [SURAH_NAMES, _1] }].compact
    end

    # The first translation of each language as `call` ranks them, the languages in the order of
    # those translations' ranks (so the sample's own comes first), at most `limit`.
    def translations(limit)
      candidates = translation_candidates
      downloads = downloads(candidates)
      rank = ->(resource) { rank(resource, Set.new, downloads) }
      candidates.group_by { |resource| resource.resource_content.language_id }
        .values.map { |resources| resources.min_by(&rank) }.sort_by(&rank).first(limit)
    end

    private

    def script_candidates
      DownloadableResource.published.where(resource_type: 'quran-script', **TYPES['quran-script'])
        .order(:id).preload(:resource_content).select { |resource| STATUSES.include?(resource.status) }
    end

    def surah_name_font
      DownloadableResource.published.where(**SURAH_NAME_FONT).order(:id)
        .select { |resource| STATUSES.include?(resource.status) && resource.catalog_name.match?(SURAH_NAME) }
        .min_by { |resource| rank(resource, Set.new, {}) }
    end

    # The published ayah-by-ayah translations a sample can be, with their language.
    def translation_candidates
      DownloadableResource.published.where(resource_type: 'translation', **TYPES['translation'])
        .preload(resource_content: :language)
        .select { |resource| STATUSES.include?(resource.status) && resource.resource_content&.language }
    end

    def rank(resource, timed, downloads)
      [resource.recommended ? 0 : 1, STATUSES.index(resource.status),
       timed.include?(resource.resource_content_id) ? 0 : 1, -downloads.fetch(resource.id, 0),
       TextKey.call(resource.catalog_name), resource.id,]
    end

    # The content ids of the surah-by-surah recitations with segment data for Al-Fatihah, the
    # surah the preview shows. Recitations are in the content database, so this is its own query.
    def timed(resources)
      content_ids = resources.select { |resource| resource.resource_type == 'recitation' }.map(&:resource_content_id)
      recitations = ::Audio::Recitation.where(resource_content_id: content_ids.compact)
        .pluck(:id, :resource_content_id).to_h
      segmented = ::Audio::Segment.where(audio_recitation_id: recitations.keys, chapter_id: 1)
        .where.not(timestamp_from: nil).distinct.pluck(:audio_recitation_id)
      recitations.values_at(*segmented).to_set
    end

    # Resource id => counted downloads of its published files.
    def downloads(resources)
      DownloadableFile.where(published: true, downloadable_resource_id: resources.map(&:id))
        .group(:downloadable_resource_id)
        .sum(Arel.sql('COALESCE(download_count, 0) + anonymous_download_count'))
    end
  end
end
