module Segments
  class ReciterPresenter < DashboardPresenter
    def reciter
      @reciter ||= Segments::Reciter.find(context.params[:id])
    end

    def segmentation_stats
      @segmentation_stats ||= calculate_segmentation_stats
    end

    def missing_ayahs_stats
      @missing_ayahs_stats ||= calculate_missing_ayahs_stats
    end

    def segmented_surahs
      @segmented_surahs ||= calculate_segmented_surahs
    end

    def total_chapters
      Chapter.count
    end

    def total_verses
      6236 # Total verses in the Quran
    end

    def overall_progress_percentage
      return 0 if total_verses == 0
      ((segmentation_stats[:total_segmented_ayahs] / total_verses.to_f) * 100).round(2)
    end

    def chapter_completion_stats
      @chapter_completion_stats ||= calculate_chapter_completion_stats
    end

    private

    # Preload all positions data to avoid N+1 queries
    def all_positions
      @all_positions ||= Segments::Position.where(reciter_id: reciter.id)
                                           .select(:surah_number, :ayah_number)
                                           .group_by(&:surah_number)
    end

    # Preload all chapter data
    def chapters_data
      @chapters_data ||= Chapter.select(:id, :verses_count, :name_simple, :name_arabic)
                                .index_by(&:id)
    end

    def calculate_segmentation_stats
      # Get all positions data grouped by surah
      positions_by_surah = all_positions

      # Count total positions (words)
      total_positions = positions_by_surah.values.flatten.count

      # Get unique chapters that have segments
      segmented_chapters = positions_by_surah.keys.compact.sort

      # Count unique ayahs that have segments
      total_segmented_ayahs = estimate_ayahs_from_positions_data(positions_by_surah)

      {
        total_segmented_ayahs: total_segmented_ayahs,
        total_segmented_words: total_positions,
        segmented_chapters_count: segmented_chapters.size,
        segmented_chapters: segmented_chapters
      }
    end

    def calculate_missing_ayahs_stats
      # Use preloaded data
      chapters_with_counts = chapters_data
      positions_by_surah = all_positions
      segmented_chapters = positions_by_surah.keys.compact

      missing_surahs = []
      missing_ayahs_by_surah = {}

      # Check each segmented chapter for missing verses
      segmented_chapters.each do |chapter_id|
        chapter = chapters_with_counts[chapter_id]
        next unless chapter

        # Get positions for this chapter from preloaded data
        chapter_positions = positions_by_surah[chapter_id] || []

        # Estimate ayahs from positions
        estimated_ayahs = estimate_ayahs_from_chapter_positions(chapter_positions)

        expected_verses = chapter.verses_count
        missing_count = expected_verses - estimated_ayahs

        if missing_count > 0 && estimated_ayahs > 0
          missing_ayahs_by_surah[chapter_id] = {
            chapter_id: chapter_id,
            chapter_name: chapter.name_simple,
            expected_verses: expected_verses,
            actual_verses: estimated_ayahs,
            missing_count: missing_count
          }
        end
      end

      # Find completely missing surahs
      all_chapter_ids = chapters_with_counts.keys
      completely_missing_surahs = all_chapter_ids - segmented_chapters

      completely_missing_surahs.each do |chapter_id|
        chapter = chapters_with_counts[chapter_id]
        missing_surahs << {
          chapter_id: chapter_id,
          chapter_name: chapter.name_simple,
          expected_verses: chapter.verses_count,
          actual_verses: 0,
          missing_count: chapter.verses_count
        }
      end

      {
        missing_surahs: missing_surahs,
        missing_ayahs_by_surah: missing_ayahs_by_surah,
        total_missing_surahs: missing_surahs.size,
        total_missing_ayahs: missing_surahs.sum { |s| s[:missing_count] } +
          missing_ayahs_by_surah.values.sum { |s| s[:missing_count] }
      }
    end

    def calculate_segmented_surahs
      chapters_data_hash = chapters_data
      positions_by_surah = all_positions
      segmented_chapters = positions_by_surah.keys.compact.sort

      segmented_chapters.map do |chapter_id|
        chapter = chapters_data_hash[chapter_id]
        next unless chapter

        # Get detailed stats for this chapter from preloaded data
        chapter_positions = positions_by_surah[chapter_id] || []

        # Estimate ayahs from positions
        estimated_ayahs = estimate_ayahs_from_chapter_positions(chapter_positions)

        completion_percentage = estimated_ayahs > 0 ?
                                  ((estimated_ayahs / chapter.verses_count.to_f) * 100).round(2) : 0

        {
          chapter_id: chapter_id,
          chapter_name: chapter.name_simple,
          verses_count: chapter.verses_count,
          segmented_verses: estimated_ayahs,
          segmented_words: chapter_positions.count,
          completion_percentage: completion_percentage
        }
      end.compact.sort_by { |s| s[:chapter_id] }
    end

    def calculate_chapter_completion_stats
      chapters_data_hash = chapters_data
      positions_by_surah = all_positions
      stats = {}

      (1..114).each do |chapter_id|
        chapter = chapters_data_hash[chapter_id]
        next unless chapter

        # Get positions for this chapter from preloaded data
        chapter_positions = positions_by_surah[chapter_id] || []

        if chapter_positions.any?
          # Estimate ayahs from positions
          estimated_ayahs = estimate_ayahs_from_chapter_positions(chapter_positions)

          completion_percentage = estimated_ayahs > 0 ?
                                    ((estimated_ayahs / chapter.verses_count.to_f) * 100).round(2) : 0
        else
          estimated_ayahs = 0
          completion_percentage = 0
        end

        stats[chapter_id] = {
          chapter_id: chapter_id,
          chapter_name: chapter.name_simple,
          expected_verses: chapter.verses_count,
          actual_verses: estimated_ayahs,
          completion_percentage: completion_percentage,
          status: completion_percentage == 100 ? 'complete' :
                    completion_percentage > 0 ? 'partial' : 'missing'
        }
      end

      stats
    end

    # Helper method to estimate ayahs from positions data (preloaded)
    # This is an approximation since we only have word-level positions
    def estimate_ayahs_from_positions_data(positions_by_surah)
      total_ayahs = 0
      positions_by_surah.each do |chapter_id, positions|
        total_ayahs += estimate_ayahs_from_chapter_positions(positions)
      end
      total_ayahs
    end

    # Helper method to estimate ayahs for a specific chapter from preloaded positions
    def estimate_ayahs_from_chapter_positions(positions)
      return 0 if positions.empty?

      # Count unique ayah numbers in the positions
      positions.map(&:ayah_number).uniq.count
    end
  end
end