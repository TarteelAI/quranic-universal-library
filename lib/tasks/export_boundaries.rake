# frozen_string_literal: true

namespace :segments do
  desc "Export ayah boundaries to JSON for boundary silence detection"
  task export_boundaries: :environment do
    reciter_id = ENV['RECITER']&.to_i || 1
    surah_number = ENV['SURAH']&.to_i || 1
    output_dir = ENV['OUTPUT_DIR'] || "tools/segments/data/boundaries/#{reciter_id}"

    puts "Exporting boundaries for Reciter #{reciter_id}, Surah #{surah_number} to #{output_dir}"

    parser = BatchAudioSegmentParser.new(data_directory: "tools/segments/data/vs_logs", reset_db: false)
    parser.export_ayah_boundaries(
      reciter: reciter_id,
      surah: surah_number,
      output_dir: output_dir
    )
  end

  desc "Refine boundaries using detected silences from find_boundary_silences.py"
  task refine_with_silences: :environment do
    reciter_id = ENV['RECITER']&.to_i
    surah_number = ENV['SURAH']&.to_i
    silences_file = ENV['SILENCES_FILE']
    data_directory = 'tools/segments/data/vs_logs'

    unless File.exist?(silences_file)
      puts "Error: Silences file not found: #{silences_file}"
      exit 1
    end

    puts "Refining boundaries for Reciter #{reciter_id}, Surah #{surah_number}"
    puts "Using silences from: #{silences_file}"

    parser = BatchAudioSegmentParser.new(data_directory: data_directory, reset_db: false)
    parser.refine_boundaries_with_detected_silences(
      reciter: reciter_id,
      surah: surah_number,
      silences_file: silences_file
    )
  end
end

