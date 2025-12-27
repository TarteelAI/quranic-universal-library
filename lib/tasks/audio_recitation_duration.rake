namespace :audio do
  desc <<-DESC
    Usage:
      # Recalculate for ALL recitations
      bin/rails audio:recalculate_total_duration
      # Recalculate for ONE recitation only
      RECITATION_ID=1 bin/rails audio:recalculate_total_duration
  DESC
  task recalculate_total_duration: :environment do
    recitation_id = ENV['RECITATION_ID']&.to_i

    recitations = if recitation_id&.positive?
                    Audio::Recitation.where(id: recitation_id)
                  else
                    Audio::Recitation.all
                  end

    puts "▶ Recalculating total_duration for #{recitations.count} recitation(s)..."

    scope = Audio::ChapterAudioFile.all
    scope = scope.where(audio_recitation_id: recitation_id) if recitation_id&.positive?

    duration_sums = scope.group(:audio_recitation_id).sum(:duration)

    recitations.find_each do |rec|
      total_seconds = duration_sums.fetch(rec.id, 0).to_i

      rec.update_columns(
        total_duration: total_seconds,
        updated_at: Time.current
      )

      h = total_seconds / 3600
      m = (total_seconds % 3600) / 60
      s = total_seconds % 60

      puts "✓ Recitation #{rec.id} (#{rec.name}) => #{total_seconds}s (#{'%02d:%02d:%02d' % [h, m, s]})"
    end

    puts "✅ Done."
  end
end
