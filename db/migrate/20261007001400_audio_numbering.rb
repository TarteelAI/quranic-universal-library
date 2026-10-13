# Phase 7, task P7.3: audio on the numbering of its riwayah.
#
# recitations.numbering_id / audio_recitations.numbering_id: the ayah
# numbering the recitation's audio is cut by, defaulting from the riwayah
# (Hafs -> Kufi, so every existing recitation gets the Kufi numbering and
# nothing changes for them).
#
# audio_segments.ayah_id / audio_files.ayah_id: the numbered ayah a segment
# or file is for, backfilled through Kufi (the Kufi numbered_ayahs carry the
# verse ids, so for Kufi recitations ayah_id = verse_id). A partial unique
# index on (audio_file_id, ayah_id) twins the (audio_file_id, verse_number)
# one so a non-Kufi recitation can be imported against its own keys.
#
# number_segments: word timings keyed by the shared word number (quran-text)
# instead of the Hafs word position; filled on save and by
# rake qiraat:backfill:number_segments. The old segments key stays.
class AudioNumbering < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    c = Verse.connection
    %i[recitations audio_recitations].each do |table|
      c.add_column table, :numbering_id, :integer
      c.add_index table, :numbering_id, algorithm: :concurrently
      c.execute <<~SQL
        UPDATE #{table} r SET numbering_id = COALESCE(
          (SELECT default_numbering_id FROM riwayat WHERE riwayat.id = r.riwayah_id),
          (SELECT id FROM ayah_numberings WHERE slug = 'kufi'))
        WHERE numbering_id IS NULL
      SQL
    end
    %i[audio_segments audio_files].each do |table|
      c.add_column table, :ayah_id, :integer
      c.add_column table, :number_segments, :jsonb
    end
    # Kufi: the numbered ayah ids equal the verse ids (P4.2)
    kufi = c.select_value("SELECT id FROM ayah_numberings WHERE slug = 'kufi'")
    if kufi
      c.execute "UPDATE audio_segments s SET ayah_id = s.verse_id FROM audio_recitations r WHERE r.id = s.audio_recitation_id AND r.numbering_id = #{kufi.to_i} AND s.verse_id IS NOT NULL AND s.ayah_id IS NULL"
      c.execute "UPDATE audio_files f SET ayah_id = f.verse_id FROM recitations r WHERE r.id = f.recitation_id AND r.numbering_id = #{kufi.to_i} AND f.verse_id IS NOT NULL AND f.ayah_id IS NULL"
    end
    c.add_index :audio_segments, :ayah_id, algorithm: :concurrently
    c.add_index :audio_files, :ayah_id, algorithm: :concurrently
    c.add_index :audio_segments, %i[audio_file_id ayah_id], unique: true, where: 'ayah_id IS NOT NULL', name: 'index_audio_segments_on_audio_file_id_and_ayah_id', algorithm: :concurrently
  end

  def down
    c = Verse.connection
    c.remove_index :audio_segments, name: 'index_audio_segments_on_audio_file_id_and_ayah_id'
    %i[audio_segments audio_files].each do |table|
      c.remove_index table, :ayah_id
      c.remove_column table, :number_segments
      c.remove_column table, :ayah_id
    end
    %i[recitations audio_recitations].each do |table|
      c.remove_index table, :numbering_id
      c.remove_column table, :numbering_id
    end
  end
end
