ActiveAdmin.register Morphology::GraphNodeEdge do
  menu parent: 'Morphology'
  actions :index, :show
  filter :type, as: :select, collection: Morphology::GraphNodeEdge.types.keys.map { |k| [k.titleize, k] }
end