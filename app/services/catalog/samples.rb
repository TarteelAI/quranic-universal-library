# frozen_string_literal: true

module Catalog
  # One published resource of each type the home page's data showcase has a tab for, chosen from
  # the resource's own fields rather than by id: a recommended resource first, then a stable one
  # before a beta one, then (recitations) one whose Al-Fatihah has segment data, so the preview
  # highlights each ayah, then the most downloaded (as the catalog's popular sort counts it), then
  # by name. Legacy and superseded resources are never shown. A type with no such resource is
  # left out. Types are in tab order.
  class Samples
    # Type => what a sample of that type must be. A recitation is surah by surah, so the preview
    # plays one file with each ayah timed; a translation is ayah by ayah.
    TYPES = {
      'recitation' => { cardinality_type: '1_chapter' },
      'mushaf-layout' => {},
      'translation' => { cardinality_type: '1_ayah' },
      'morphology' => {},
    }.freeze
    STATUSES = ['stable', 'beta'].freeze

    # Type => DownloadableResource.
    def call
      candidates = TYPES.map do |type, conditions|
        DownloadableResource.published.where(resource_type: type, status: STATUSES, **conditions)
      end.reduce(:or).to_a
      downloads = downloads(candidates)
      timed = timed(candidates)

      candidates.group_by(&:resource_type).transform_values do |resources|
        resources.min_by { |resource| rank(resource, timed, downloads) }
      end.slice(*TYPES.keys)
    end

    private

    def rank(resource, timed, downloads)
      [resource.recommended ? 0 : 1, STATUSES.index(resource.status),
       timed.include?(resource.resource_content_id) ? 0 : 1, -downloads.fetch(resource.id, 0),
       TextKey.call(resource.display_name), resource.id,]
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
