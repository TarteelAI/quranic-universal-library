# == Schema Information
#
# Table name: topics
#
#  id                  :integer          not null, primary key
#  arabic_name         :string
#  ayah_range          :string
#  childen_count       :integer          default(0)
#  depth               :integer          default(0)
#  description         :text
#  name                :string
#  ontology            :boolean
#  relatd_topics_count :integer          default(0)
#  thematic            :boolean
#  wikipedia_link      :string
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  ontology_parent_id  :integer
#  parent_id           :integer
#  resource_content_id :integer
#  thematic_parent_id  :integer
#
# Indexes
#
#  index_topics_on_depth               (depth)
#  index_topics_on_name                (name)
#  index_topics_on_ontology            (ontology)
#  index_topics_on_ontology_parent_id  (ontology_parent_id)
#  index_topics_on_parent_id           (parent_id)
#  index_topics_on_thematic            (thematic)
#  index_topics_on_thematic_parent_id  (thematic_parent_id)
#


class Topic < QuranApiRecord
  include NameTranslateable
  include NavigationSearchable
  include Resourceable

  #TODO: add ancestry https://github.com/stefankroes/ancestry
  # or https://github.com/mdub/arboreal
  belongs_to :parent, class_name: 'Topic', optional: true
  belongs_to :thematic_parent, class_name: 'Topic', optional: true
  belongs_to :ontology_parent, class_name: 'Topic', optional: true

  has_many :children, class_name: 'Topic', foreign_key: 'parent_id'
  has_many :ontology_children, class_name: 'Topic', foreign_key: 'ontology_parent_id'
  has_many :thematic_children, class_name: 'Topic', foreign_key: 'thematic_parent_id'

  has_many :related_topics
  has_many :verse_topics

  def self.roots
    where(parent_id: nil)
  end

  def ayah_keys
    verse_topics.map do |vt|
      vt.verse.verse_key
    end
  end

  # copied from https://github.com/amerine/acts_as_tree/blob/master/lib/acts_as_tree.rb#L175
  def self.tree_view(label_method = :name,  node = nil, level = -1)
    if node.nil?
      puts "root"
      nodes = roots
    else
      label = "|_ #{node.send(label_method)}"
      if level == 0
        puts " #{label}"
      else
        puts " |#{"    "*level}#{label}"
      end
      nodes = node.children
    end
    nodes.each do |child|
      tree_view(label_method, child, level+1)
    end
  end
end
