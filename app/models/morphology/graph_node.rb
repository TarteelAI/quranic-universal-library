# == Schema Information
#
# Table name: morphology_graph_nodes
#
#  id            :bigint           not null, primary key
#  number        :integer
#  pos           :string
#  resource_type :string
#  type          :integer
#  value         :string
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  graph_id      :bigint
#  resource_id   :bigint
#  segment_id    :integer
#
# Indexes
#
#  index_morphology_graph_nodes_on_graph_id  (graph_id)
#  index_morphology_graph_nodes_on_resource  (resource_type,resource_id)
#  index_morphology_graph_nodes_on_type      (type)
#
# Foreign Keys
#
#  fk_rails_...  (graph_id => morphology_graphs.id)
#
class Morphology::GraphNode < QuranApiRecord
  self.inheritance_column = :_type
  
  attr_accessor :temp_number, :temp_id
  
  belongs_to :graph, class_name: 'Morphology::Graph', optional: true
  belongs_to :segment, class_name: 'Morphology::WordSegment', foreign_key: :segment_id, optional: true
  belongs_to :resource, polymorphic: true, optional: true
  
  has_many :outgoing_edges, class_name: 'Morphology::GraphNodeEdge', foreign_key: :source_id, dependent: :destroy
  has_many :incoming_edges, class_name: 'Morphology::GraphNodeEdge', foreign_key: :target_id, dependent: :destroy
  
  has_one :source_edge, class_name: 'Morphology::GraphNodeEdge', foreign_key: :source_id
  has_one :target_edge, class_name: 'Morphology::GraphNodeEdge', foreign_key: :target_id

  delegate :chapter_number, :verse_number, :graph_number, to: :graph, allow_nil: true

  enum type: {
    word: 0,
    reference: 1,
    phrase: 2,
    elided: 3
  }

  scope :chapter_eq, lambda {|chapter_number|
    joins(:graph).where('morphology_graphs.chapter_number = ?', chapter_number)
  }

  scope :word_eq, lambda {|word_id|
    joins(:graph).where('morphology_graphs.word_id = ?', word_id)
  }

  scope :verse_eq, lambda {|verse_number|
    joins(:graph).where('morphology_graphs.verse_number = ?', verse_number)
  }

  alias_method :morphology_word, :resource

  def self.ransackable_scopes(*)
    %i[chapter_eq verse_eq word_eq]
  end

  def location
    case type
    when 'word'
      resource.location
    when 'reference'
      resource.present? ? resource.location : nil
    else
      "#{type} #{resource&.id}"
    end
  end
  
  def display_number
    temp_number.presence || "n#{number + 1}"
  end
  
  def node_id
    temp_id.presence || id
  end
end
