class CreateMorphologyGraphs < ActiveRecord::Migration[7.0]
  def change
    c = Word.connection
    c.create_table :morphology_graphs do |t|
      t.integer :chapter_id, null: false
      t.integer :verse_id, null: false
      t.integer :graph_number, null: false, default: 1

      t.timestamps
    end

    c.add_index :morphology_graphs, [:chapter_id, :verse_id], name: 'index_morphology_graphs_on_chapter_verse'
    c.add_index :morphology_graphs, [:chapter_id, :verse_id, :graph_number], unique: true, name: 'index_morphology_graphs_on_chapter_verse_graph'
  end

  def down
    c = Word.connection
    c.drop_table :morphology_graphs, if_exists: true
  end
end
