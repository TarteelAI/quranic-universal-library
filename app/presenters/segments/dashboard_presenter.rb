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

        ayah_positions = ::Segments::Position.where(reciter_id: reciter.id, surah_number: selected_surah).order(:ayah_number)
        word_positions = ayah_positions.index_by(&:word_key)
        ayah_boundaries = ::Segments::AyahBoundary.where(reciter_id: reciter.id, surah_number: selected_surah).order(:ayah_number)
        ayahs = Verse.where(chapter_id: selected_surah).order(:verse_number)
        grouped_ayah_positions = ayah_positions.group_by(&:ayah_number)

        ayah_boundaries.each do |boundary|
          words_data = grouped_ayah_positions[boundary.ayah_number]&.map do |pos|
            [
              pos.word_number,
              pos.start_time,
              pos.end_time,
            ]
          end

          boundary.set_words_data(words_data)
        end

        {
          reciter: reciter,
          failures: failures,
          ayah_positions: grouped_ayah_positions,
          word_positions: word_positions,
          ayahs: ayahs,
          ayah_boundaries: ayah_boundaries.index_by(&:ayah_number)
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
      ::Segments::Database.order('id DESC')
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
        missing_words = failures.where(failure_type: 'MISSED_WORD')

        {
          id: reciter.id,
          name: reciter.name,
          positions: positions.count,
          failures: failures.count,
          corrected_failures: corrections,
          pending_failures: failures.count - corrections,
          pending_percentage: ((failures.count - corrections) / failures.count.to_f * 100).round(2),
          corrected_percentage: (corrections / failures.count.to_f * 100).round(2),
          missing_words: missing_words.size,
          missing_words_percentage: (missing_words.size / failures.count.to_f * 100).round(2),
          corrected_missing_words: missing_words.where(corrected: true).size,
          corrected_missing_words_percentage: (missing_words.where(corrected: true).size / missing_words.size.to_f * 100).round(2)
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
      word_search = params[:word_search].to_s.strip

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

      if word_search.present?
        list = list.where("expected_transcript LIKE ? OR received_transcript LIKE ?", "%#{word_search}%", "%#{word_search}%")
      end

      correction_status = params[:correction_status].to_s.strip
      if correction_status == 'corrected'
        list = list.where(corrected: true)
      elsif correction_status == 'pending'
        list = list.where(corrected: false)
      end

      list
    end

    # Word failure statistics methods
    def word_failure_stats
      failures = filter_failures
      
      # Group by expected_transcript (correct word)
      grouped_failures = failures.group_by(&:expected_transcript)
      
      grouped_failures.map do |expected_word, word_failures|
        {
          word: expected_word,
          fail_count: word_failures.count,
          unique_reciters: word_failures.map(&:reciter_id).uniq.count,
          mistaken_variants: word_failures.map(&:received_transcript).uniq.sort,
          reciter_ids: word_failures.map(&:reciter_id).uniq.sort,
          mistake_types: word_failures.map(&:failure_type).uniq,
          surah_ayah_pairs: word_failures.map { |f| "#{f.surah_number}:#{f.ayah_number}" }.uniq.sort,
          reciter_breakdown: word_failures.group_by(&:reciter_id).transform_values(&:count),
          corrected_count: word_failures.count(&:corrected),
          pending_count: word_failures.count { |f| !f.corrected }
        }
      end.sort_by { |stats| -stats[:fail_count] }
    end

    def word_failure_stats_paginated
      pagy(word_failure_stats)
    end

    def word_failure_summary
      failures = filter_failures
      
      {
        total_failures: failures.count,
        unique_words_with_failures: failures.distinct.count(:expected_transcript),
        unique_reciters: failures.distinct.count(:reciter_id),
        unique_surahs: failures.distinct.count(:surah_number),
        total_corrected: failures.where(corrected: true).count,
        total_pending: failures.where(corrected: false).count,
        correction_rate: calculate_correction_rate(failures)
      }
    end

    def top_problematic_words(limit = 10)
      word_failure_stats.first(limit)
    end

    def reciter_word_failure_breakdown
      failures = filter_failures
      reciter_stats = {}
      
      failures.group_by(&:reciter_id).each do |reciter_id, reciter_failures|
        reciter = ::Segments::Reciter.find_by(id: reciter_id)
        next unless reciter
        
        word_groups = reciter_failures.group_by(&:expected_transcript)
        
        reciter_stats[reciter_id] = {
          reciter_name: reciter.name,
          total_failures: reciter_failures.count,
          unique_problematic_words: word_groups.count,
          top_words: word_groups.map do |word, word_failures|
            {
              word: word,
              count: word_failures.count,
              variants: word_failures.map(&:received_transcript).uniq
            }
          end.sort_by { |w| -w[:count] }.first(5)
        }
      end
      
      reciter_stats
    end

    private

    def calculate_correction_rate(failures)
      total = failures.count
      return 0.0 if total == 0
      
      corrected = failures.where(corrected: true).count
      (corrected.to_f / total * 100).round(2)
    end
  end
end