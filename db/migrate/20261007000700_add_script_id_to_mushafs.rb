# Phase 3, task P3.4: which script a mushaf's words are cached from.
#
# mushaf_words.text is a render cache copied from one script. Until now the
# source was chosen by hard-coded mushaf ids and name matching; script_id
# names it. Backfilled by rake qiraat:backfill:mushaf_scripts, which detects
# the script from the cached text itself.
class AddScriptIdToMushafs < ActiveRecord::Migration[8.0]
  def up
    c = Verse.connection
    c.add_column :mushafs, :script_id, :integer
    c.add_index :mushafs, :script_id
  end

  def down
    c = Verse.connection
    c.remove_index :mushafs, :script_id
    c.remove_column :mushafs, :script_id
  end
end
