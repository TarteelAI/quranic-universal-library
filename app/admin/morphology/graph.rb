ActiveAdmin.register Morphology::DependencyGraph::Graph, as: 'Graph' do
  menu parent: 'Morphology'
  actions :index, :show

  filter :chapter, as: :searchable_select,
         ajax: { resource: Chapter }
  filter :verse, as: :searchable_select,
         ajax: { resource: Verse }
  filter :graph_number

  controller do
    def scoped_collection
      super.select("morphology_dependency_graphs.*, (chapter_number * 10000 + verse_number * 100 + graph_number) as verse_key_sort")
    end
  end

  action_item :edit, only: :show do
    link_to 'Edit Graph', edit_morphology_dependency_graph_path(resource), target: '_blank'
  end

  show do
    attributes_table do
      row :id
      row :chapter do |graph|
        link_to graph.chapter.name, [:cms, graph.chapter]
      end
      row :verse do |graph|
        link_to graph.verse.verse_key, [:cms, graph.verse]
      end
      row :graph_number
      row :created_at
      row :updated_at
    end

    panel 'Graph Visualization' do
      render partial: 'admin/morphology/graph/show', locals: {
        graph: resource
      }
    end
  end

  index do
    id_column
    column :verse_key, sortable: :verse_key_sort
    column :graph_number, sortable: :graph_number
    column :created_at
    column :updated_at
    actions
  end
end