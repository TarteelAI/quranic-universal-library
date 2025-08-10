module Segments
  class DashboardPresenter < ApplicationPresenter
    def graph_data
      stats = ::Segments::Detection.all
      stats = stats.where(reciter_id: selected_reciter.to_i) if selected_reciter.present?
      stats = stats.where(surah_number: selected_surah.to_i) if selected_surah.present?

      detection_counts = stats.group(:detection_type).sum(:count)
      failures_list = filter_failures

      {
        detections: detection_counts,
        failures: failures_list,
        mistake_types: failures_list.group(:failure_type).count,
      }
    end

    def timeline_data
      if selected_surah.present? && selected_reciter.present?
        reciter = ::Segments::Reciter.find(selected_reciter)

        failures = filter_failures.index_by do |f|
          if f.word_key.blank?
            f.mistake_positions.to_s.split(',').first
          else
            f.word_key
          end
        end

        ayah_positions = ::Segments::Position.where(reciter_id: reciter.id, surah_number: selected_surah).order(:ayah_number).group_by(&:ayah_number)
        word_positions = ::Segments::Position.where(reciter_id: reciter.id, surah_number: selected_surah).order(:ayah_number).index_by(&:word_key)
        ayahs = Verse.where(chapter_id: selected_surah).order(:verse_number)

        {
          reciter: reciter,
          failures: failures,
          ayah_positions: ayah_positions,
          word_positions: word_positions,
          ayahs: ayahs
        }
      end
    end

    def failures
      pagy(filter_failures)
    end

    def ayah_failures
      list = filter_failures.joins(:reciter)

      list
        .select(
          'surah_number',
          'ayah_number',
          'GROUP_CONCAT(DISTINCT segments_reciters.id) AS reciters',
          'GROUP_CONCAT(DISTINCT failure_type) AS failure_types',
          'COUNT(*) AS total_failures'
        )
        .group(:surah_number, :ayah_number)
        .order(:surah_number, :ayah_number)
    end

    def segmented_surah
      @surahs ||= ::Segments::Detection.distinct.pluck(:surah_number).sort
    end

    def segment_databases

    end

    def reciters
      ::Segments::Reciter.all
    end

    def chapter_options
      Chapter.order('id asc').map do |c|
        [
          c.humanize,
          c.id
        ]
      end
    end

    def reciter_stats
      s = selected_surah

      reciters.map do |reciter|
        positions = ::Segments::Position.where(reciter_id: reciter.id)
        failures = ::Segments::Failure.where(reciter_id: reciter.id)

        if s.present?
          positions = positions.where(surah_number: s)
          failures = failures.where(surah_number: s)
        end

        corrections = failures.where(corrected: true).count

        {
          id: reciter.id,
          name: reciter.name,
          positions: positions.count,
          failures: failures.count,
          corrected_failures: corrections,
          pending_failures: failures.count - corrections,
          pending_percentage: ((failures.count - corrections) / failures.count.to_f * 100).round(2),
          corrected_percentage: (corrections / failures.count.to_f * 100).round(2),
        }
      end
    end

    def selected_surah
      params[:surah].to_i if params[:surah].present?
    end

    def selected_reciter
      params[:reciter].to_i if params[:reciter].present?
    end

    def filter_failures
      expected_text = params[:expected_text].to_s.strip
      received_text = params[:received_text].to_s.strip
      failure_type = params[:failure_type].to_s.strip

      list = ::Segments::Failure.all
      list = list.where(reciter_id: selected_reciter) if selected_reciter.present?
      list = list.where(surah_number: selected_surah) if selected_surah.present?

      if expected_text.present?
        list = list.where("expected_transcript LIKE ?", "%#{expected_text}%")
      end

      if received_text.present?
        list = list.where("received_transcript LIKE ?", "%#{received_text}%")
      end

      if failure_type.present?
        list = list.where(failure_type: failure_type)
      end

      correction_status = params[:correction_status].to_s.strip
      if correction_status == 'corrected'
        list = list.where(corrected: true)
      elsif correction_status == 'pending'
        list = list.where(corrected: false)
      end

      list
    end
  end
end