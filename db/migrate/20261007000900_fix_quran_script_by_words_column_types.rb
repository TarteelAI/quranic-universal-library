# Phase 3, task P3.7: quran_script_by_words was created with its key columns
# typed as string (see 20241228080711); every value is numeric. Cast them to
# integer so the legacy rows can be joined like any other table.
class FixQuranScriptByWordsColumnTypes < ActiveRecord::Migration[8.0]
  COLUMNS = %i[qirat_id resource_content_id verse_id word_id].freeze

  def up
    c = Verse.connection
    COLUMNS.each do |col|
      c.execute "ALTER TABLE quran_script_by_words ALTER COLUMN #{col} TYPE integer USING NULLIF(#{col}, '')::integer"
    end
  end

  def down
    c = Verse.connection
    COLUMNS.each do |col|
      c.execute "ALTER TABLE quran_script_by_words ALTER COLUMN #{col} TYPE varchar USING #{col}::varchar"
    end
  end
end
