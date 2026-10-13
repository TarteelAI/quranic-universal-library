# frozen_string_literal: true

module Qiraat
  module Backfill
    # audio_segments.ayah_id / audio_files.ayah_id from the recitation's
    # numbering (P7.3): Kufi recitations get the verse id (the Kufi numbered
    # ayahs carry it); any other numbering goes through AyahMapping for the
    # row's verse (a split verse's row keeps the first ayah). Idempotent:
    # only rows with a verse and no ayah are touched.
    class AudioAyahIds
      def initialize(dry_run: false)
        @dry_run = dry_run
        @report = Hash.new(0)
      end

      def call
        kufi = AyahNumbering.kufi
        [[Audio::Segment, Audio::Recitation, :audio_recitation_id], [AudioFile, Recitation, :recitation_id]].each do |model, owner, fk|
          owner.where.not(numbering_id: nil).find_each do |rec|
            scope = model.where(fk => rec.id).where.not(verse_id: nil).where(ayah_id: nil)
            if rec.numbering_id == kufi.id
              n = @dry_run ? scope.count : scope.update_all('ayah_id = verse_id')
              @report["#{model.table_name}_kufi"] += n
            else
              scope.find_each do |row|
                ayah_id = AyahMapping.find_by(numbering_id: rec.numbering_id, verse_id: row.verse_id)&.ayah_id
                next unless ayah_id

                row.update_column(:ayah_id, ayah_id) unless @dry_run
                @report["#{model.table_name}_mapped"] += 1
              end
            end
          end
        end
        @report
      end
    end
  end
end
