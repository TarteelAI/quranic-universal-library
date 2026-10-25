namespace :audio do
  # Freezes the version clients are already holding, so that switching the
  # manifest from `updated_at` to `content_version` doesn't look like a change
  # to anyone. Run this once, before the first export after the switch.
  desc 'Seed content_version from updated_at for audio files that have never been fingerprinted'
  task backfill_content_versions: :environment do
    [Audio::ChapterAudioFile, AudioFile].each do |klass|
      scope = klass.where(content_version: nil).or(klass.where(content_version: 0))
      total = scope.count
      updated = 0

      puts "#{klass}: #{total} files to seed"

      scope.find_each do |audio_file|
        audio_file.update_columns(
          content_version: audio_file.updated_at.to_i,
          content_version_source: 'backfill'
        )
        updated += 1
        puts "  #{updated}/#{total}" if (updated % 500).zero?
      end

      puts "#{klass}: seeded #{updated} files"
    end
  end
end
