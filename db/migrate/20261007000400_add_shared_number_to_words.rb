# Phase 2, task P2.1: the shared word number on words.
#
# number       the quran-text shared number (1..77434), the same integer for the
#              same word in every riwayah; NULL on ayah-end rows until backfilled
# number_last  set only where one Hafs word covers two shared numbers (72:16:1)
# hafs_reads   false for the rare word Hafs does not read (9:101, number 25685)
# sub_position orders such a word after its Hafs neighbour without renumbering
#
# Columns only; the backfill is rake qiraat:backfill:word_numbers (P2.2).
class AddSharedNumberToWords < ActiveRecord::Migration[8.0]
  def up
    c = Verse.connection
    c.add_column :words, :number, :integer
    c.add_column :words, :number_last, :integer
    c.add_column :words, :hafs_reads, :boolean, null: false, default: true
    c.add_column :words, :sub_position, :integer, null: false, default: 0
    c.add_index :words, :number, unique: true, where: 'number IS NOT NULL', name: 'index_words_on_number'
  end

  def down
    c = Verse.connection
    c.remove_index :words, name: 'index_words_on_number'
    c.remove_column :words, :sub_position
    c.remove_column :words, :hafs_reads
    c.remove_column :words, :number_last
    c.remove_column :words, :number
  end
end
