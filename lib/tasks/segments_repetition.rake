# frozen_string_literal: true

# Recomputes has_repetition for existing segments: repeats within an ayah and
# returns to an earlier ayah (Audio::Segment.track_repetition!). Imports do
# this themselves; this is the backfill.
#
#   bin/rails segments:track_repetition                 # every surah-by-surah recitation
#   bin/rails segments:track_repetition IDS=175,65
namespace :segments do
  desc 'Recompute has_repetition, including returns to an earlier ayah (IDS=1,2 to limit)'
  task track_repetition: :environment do
    tokens = ENV['IDS'].to_s.split(',').map(&:strip).reject(&:blank?)
    invalid = tokens.grep_v(/\A\d+\z/)
    abort "IDS must be recitation ids separated by commas, got: #{invalid.join(', ')}" if invalid.any?

    ids = tokens.map(&:to_i).presence
    ids ||= Audio::Segment.distinct.order(:audio_recitation_id).pluck(:audio_recitation_id)

    ids.each do |id|
      started = Time.current
      changed = Audio::Segment.track_repetition!(id)
      cross = Audio::Segment.where(audio_recitation_id: id).has_cross_ayah_repeat.count
      puts format('#%-5s %5d changed, %4d cross-ayah, %.1fs', id, changed, cross, Time.current - started)
    end
  end
end
