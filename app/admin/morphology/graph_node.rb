ActiveAdmin.register Morphology::GraphNode do
  menu parent: 'Morphology'
  actions :index, :show

  filter :type, as: :select, collection: Morphology::GraphNode.types.keys.map { |k| [k.titleize, k] }
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
      collection = super.includes(:graph)
      collection = collection.by_chapter(params[:chapter]) if params[:chapter].present?
      collection = collection.by_verse(params[:verse]) if params[:verse].present?
      collection
    end
  end

  index do
    selectable_column
    id_column
    column :type do |node|
      node.type&.titleize
    end
    column :chapter do |node|
      node.chapter_id
    end
    column :verse do |node|
      node.verse_id
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
        node.chapter_id
      end
      row :verse do |node|
        node.verse_id
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