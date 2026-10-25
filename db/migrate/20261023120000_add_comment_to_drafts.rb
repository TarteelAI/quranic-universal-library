# The contributor's note to the reviewer: what they changed and why.
class AddCommentToDrafts < ActiveRecord::Migration[8.0]
  TABLES = %i[draft_translations draft_tafsirs draft_transliterations draft_word_transliterations draft_surah_infos].freeze

  def up
    TABLES.each { |table| add_column table, :comment, :text }

    # Translation comments used to be kept in meta_data
    execute <<~SQL
      UPDATE draft_translations
      SET comment = meta_data->>'comment', meta_data = meta_data - 'comment'
      WHERE meta_data ? 'comment'
    SQL
  end

  def down
    execute <<~SQL
      UPDATE draft_translations
      SET meta_data = COALESCE(meta_data, '{}'::jsonb) || jsonb_build_object('comment', comment)
      WHERE comment IS NOT NULL
    SQL

    TABLES.each { |table| remove_column table, :comment }
  end
end
