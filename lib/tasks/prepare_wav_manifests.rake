# frozen_string_literal: true

namespace :audio do
  desc "Prepare wav manifest for a specific recitation"
  task :prepare_recitation_manifest, [:recitation_id] => :environment do |task, args|
    recitation_id = args[:recitation_id]

    unless recitation_id
      puts "Usage: rake audio:prepare_recitation_manifest[RECITATION_ID]"
      exit 1
    end

    recitation = Audio::Recitation.find(recitation_id)
    puts "Preparing wav manifests for recitation: #{recitation.name}"

    audio_files = Audio::ChapterAudioFile
                    .where(audio_recitation: recitation)
                    .includes(:chapter)

    audio_files.find_each do |audio_file|
      puts "Processing #{audio_file.humanize}..."

      begin
        audio_file.prepare_wav_manifest!
        puts "  ✓ Prepared manifest with #{audio_file.wav_parts.count} parts"
      rescue => e
        puts "  ✗ Error: #{e.message}"
      end
    end

    puts "Wav manifest preparation completed for #{recitation.name}!"
  end
end

