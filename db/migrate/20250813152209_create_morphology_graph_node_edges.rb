class CreateMorphologyGraphNodeEdges < ActiveRecord::Migration[7.0]
  def up
    c = Word.connection
    c.create_table :morphology_graph_node_edges do |t|
      t.integer :source_id
      t.integer :target_id
      t.string :relation
      t.integer :type, default: 0
      t.timestamps
    end
    c.add_index :morphology_graph_node_edges, :source_id
    c.add_index :morphology_graph_node_edges, :target_id
    c.add_index :morphology_graph_node_edges, :relation
    c.add_index :morphology_graph_node_edges, :type
  end

  def down
    c = Word.connection
    c.remove_index :morphology_graph_node_edges, :source_id
    c.remove_index :morphology_graph_node_edges, :target_id
    c.remove_index :morphology_graph_node_edges, :relation
    c.remove_index :morphology_graph_node_edges, :type
    c.drop_table :morphology_graph_node_edges
  end
end
