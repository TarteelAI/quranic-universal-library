# Phase 5, task P5.2: the layout tables know their numbered ayahs.
#
# mushaf_words.ayah_id      the numbered ayah (in the mushaf's numbering) each
#                           cached word or marker belongs to; direct "words of
#                           ayah X on page P" lookups without going through Kufi
# mushaf_words.word_id      nullable: an ayah-end marker of a non-Kufi
#                           numbering has no words row behind it
# mushaf_pages.first/last_ayah_id   the page's ayah range in its numbering
#
# Backfilled from ayah_mappings by rake qiraat:backfill:mushaf_ayah_ids.
class AddAyahIdsToMushafLayout < ActiveRecord::Migration[8.0]
  def up
    c = Verse.connection
    c.add_column :mushaf_words, :ayah_id, :integer
    c.add_index :mushaf_words, %i[mushaf_id ayah_id], name: 'index_mushaf_words_on_mushaf_and_ayah'
    c.change_column_null :mushaf_words, :word_id, true
    c.add_column :mushaf_pages, :first_ayah_id, :integer
    c.add_column :mushaf_pages, :last_ayah_id, :integer
  end

  def down
    c = Verse.connection
    c.remove_column :mushaf_pages, :last_ayah_id
    c.remove_column :mushaf_pages, :first_ayah_id
    c.remove_index :mushaf_words, name: 'index_mushaf_words_on_mushaf_and_ayah'
    c.remove_column :mushaf_words, :ayah_id
  end
end
