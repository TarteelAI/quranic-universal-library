class RenameGraphVerseIdToVerseNumber < ActiveRecord::Migration[7.0]
  def change
    c = Verse.connection
    c.rename_column :morphology_graphs, :verse_id, :verse_number
    c.rename_column :morphology_graphs, :chapter_id, :chapter_number
    c.rename_index :morphology_graphs, 'index_morphology_graphs_on_chapter_verse', 'index_morphology_graphs_on_chapter_verse_number'
  end
end
