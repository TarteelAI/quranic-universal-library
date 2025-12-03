class CreateMorphologyGraphNodes < ActiveRecord::Migration[7.0]
  def up
    c = Word.connection
    c.create_table :morphology_graph_nodes do |t|
      t.references :graph, foreign_key: { to_table: :morphology_graphs }, index: true
      t.references :resource, polymorphic: true, index: true
      t.integer :segment_id
      t.string :pos
      t.integer :type
      t.string :value
      t.integer :number
      t.timestamps
    end
    
    c.add_index :morphology_graph_nodes, :type
    # c.add_column :morphology_words, :index, :integer
    # c.add_index :morphology_words, :index
    # ::Morphology::Word.find_each do |word|
    #   word.update_column(:index, ::Morphology::Word.where('verse_id < ?', word.verse_id).count + word.location.split(':').last&.to_i)
    # end
  end

  def down
    c = Word.connection
    c.drop_table :morphology_graph_nodes, if_exists: true
    # c.remove_column :morphology_words, :index, if_exists: true
  end
end
