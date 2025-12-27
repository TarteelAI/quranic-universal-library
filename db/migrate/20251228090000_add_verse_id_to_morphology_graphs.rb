class AddVerseIdToMorphologyGraphs < ActiveRecord::Migration[7.0]
  def up
    c = Verse.connection
    c.add_column :morphology_graphs, :verse_id, :integer
    c.execute <<~SQL
      UPDATE morphology_graphs g
      SET verse_id = v.id
      FROM verses v
      WHERE v.chapter_id = g.chapter_number
        AND v.verse_number = g.verse_number
    SQL
    c.add_index :morphology_graphs, :verse_id
    c.add_index :morphology_graphs, [:verse_id, :graph_number]
  end

  def down
    c = Verse.connection
    c.remove_index :morphology_graphs, column: [:verse_id, :graph_number]
    c.remove_index :morphology_graphs, :verse_id
    c.remove_column :morphology_graphs, :verse_id
  end
end


