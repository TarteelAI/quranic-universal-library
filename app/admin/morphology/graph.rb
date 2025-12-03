ActiveAdmin.register Morphology::Graph, as: 'Graph' do
  menu parent: 'Morphology'
  config.filters = false
  config.sort_order = "chapter_id_asc"
  
  actions :all, except: [:new, :create, :destroy, :edit, :update]

  action_item :edit, only: :show do
    link_to 'Edit Graph', edit_morphology_treebank_index_path(
      chapter_id: resource.chapter_id,
      verse_id: resource.verse_id,
      graph_number: resource.graph_number
    ), target: '_blank'
  end

  show do
    render partial: 'admin/morphology/graph/show', locals: {
      graph: resource
    }
  end

  index do
    id_column
    column :verse_key
    column :graph_number
    column :created_at
    column :updated_at
    actions defaults: false do |graph|
      link_to 'View', cms_graph_path(graph), class: 'member_link'
    end
  end
end