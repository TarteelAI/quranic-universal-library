# frozen_string_literal: true

module Qiraat
  module Backfill
    # Writes number_segments — [[shared word number, from, to], ...] — beside
    # the position-keyed segments of audio_segments and audio_files (P7.3).
    # Rows are grouped by verse so each verse's position -> number map is
    # read once; a position with no number (a continuation row, 15:7:2) is
    # skipped. Idempotent: rows with number_segments already set are left.
    class NumberSegments
      def initialize(dry_run: false, only: nil, logger: $stdout)
        @dry_run = dry_run
        @only = only # 'audio_segments' | 'audio_files' | nil for both
        @logger = logger
        @report = Hash.new(0)
      end

      def call
        [[Audio::Segment, 'audio_segments'], [AudioFile, 'audio_files']].each do |model, name|
          next if @only && @only != name

          verse_ids = model.where(number_segments: nil).where.not(verse_id: nil).distinct.pluck(:verse_id)
          verse_ids.each_slice(200) do |ids|
            numbers = Word.unscoped.where(verse_id: ids, char_type_name: 'word').pluck(:verse_id, :position, :number).group_by(&:first).transform_values { |rows| rows.to_h { |_v, pos, num| [pos, num] } }
            model.where(verse_id: ids, number_segments: nil).find_each do |row|
              list = Audio::Segment.number_segments_for(row.get_segments(drop_metadata: true), numbers[row.verse_id] || {})
              @report[name] += 1
              row.update_column(:number_segments, list) unless @dry_run
            end
          end
          @logger&.puts("  #{name}: #{@report[name]} rows#{@dry_run ? ' (dry run)' : ''}")
        end
        @report
      end
    end
  end
end
