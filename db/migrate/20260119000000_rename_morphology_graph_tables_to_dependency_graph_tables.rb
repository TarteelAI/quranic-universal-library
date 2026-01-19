class RenameMorphologyGraphTablesToDependencyGraphTables < ActiveRecord::Migration[7.0]
  def up
    c = Verse.connection

    c.rename_table :morphology_graphs, :morphology_dependency_graphs
    c.rename_table :morphology_graph_nodes, :morphology_dependency_graph_nodes
    c.rename_table :morphology_graph_node_edges, :morphology_dependency_graph_node_edges
    c.add_column :morphology_dependency_graphs,:review_status, :integer

    c.execute <<~SQL
      UPDATE morphology_dependency_graph_nodes
      SET resource_type = 'Morphology::DependencyGraph::GraphNodeEdge'
      WHERE resource_type = 'Morphology::GraphNodeEdge'
    SQL

    %w[
      morphology_dependency_graphs
      morphology_dependency_graph_nodes
      morphology_dependency_graph_node_edges
    ].each do |t|
      c.reset_pk_sequence!(t)
    end
  end

  def down
    c = Verse.connection

    c.execute <<~SQL
      UPDATE morphology_dependency_graph_nodes
      SET resource_type = 'Morphology::GraphNodeEdge'
      WHERE resource_type = 'Morphology::DependencyGraph::GraphNodeEdge'
    SQL

    c.rename_table :morphology_dependency_graph_node_edges, :morphology_graph_node_edges
    c.rename_table :morphology_dependency_graph_nodes, :morphology_graph_nodes
    c.rename_table :morphology_dependency_graphs, :morphology_graphs
  end
end

