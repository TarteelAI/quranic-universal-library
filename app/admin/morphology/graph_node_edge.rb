ActiveAdmin.register Morphology::DependencyGraph::GraphNodeEdge do
  menu parent: 'Morphology'
  actions :index, :show
  filter :type, as: :select, collection: Morphology::DependencyGraph::GraphNodeEdge.types.keys.map { |k| [k.titleize, k] }
end