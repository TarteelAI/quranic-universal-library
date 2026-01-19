ActiveAdmin.register Morphology::DependencyGraph::GraphNode do
  menu parent: 'Morphology'
  actions :index, :show

  filter :type, as: :select, collection: Morphology::DependencyGraph::GraphNode.types.keys.map { |k| [k.titleize, k] }
  filter :resource_type, as: :select, collection: ['Word', 'Verse']
  filter :chapter, as: :searchable_select,
         ajax: { resource: Chapter }
  filter :verse, as: :searchable_select,
         ajax: { resource: Verse }
  filter :word, as: :searchable_select,
         ajax: { resource: Word }
  filter :pos

  controller do
    def scoped_collection
      super.includes(:graph)
    end
  end

  index do
    selectable_column
    id_column
    column :type do |node|
      node.type&.titleize
    end
    column :chapter do |node|
      node.chapter_number
    end
    column :verse do |node|
      node.verse_number
    end
    column :location
    column :resource_type
    column :resource_id
    column :value
    column :pos
    column :number
    actions
  end

  show do
    attributes_table do
      row :id
      row :type do |node|
        node.type&.titleize
      end
      row :chapter do |node|
        node.chapter_number
      end
      row :verse do |node|
        node.verse_number
      end
      row :location
      row :graph
      row :resource_type
      row :resource_id
      row :resource
      row :segment
      row :value
      row :pos
      row :number
      row :created_at
      row :updated_at
    end
  end
end