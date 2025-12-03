# == Schema Information
#
# Table name: topics
#
#  id                  :integer          not null, primary key
#  arabic_name         :string
#  ayah_range          :string
#  children_count      :integer          default(0)
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

  # TODO: add ancestry https://github.com/stefankroes/ancestry
  # or https://github.com/mdub/arboreal
  belongs_to :parent, class_name: 'Topic', optional: true
  belongs_to :thematic_parent, class_name: 'Topic', optional: true
  belongs_to :ontology_parent, class_name: 'Topic', optional: true

  has_many :children, class_name: 'Topic', foreign_key: 'parent_id'
  has_many :ontology_children, class_name: 'Topic', foreign_key: 'ontology_parent_id'
  has_many :thematic_children, class_name: 'Topic', foreign_key: 'thematic_parent_id'

  has_many :related_topics
  has_many :verse_topics
  has_many :verses, through: :verse_topics

  scope :verse_id_eq, lambda {|verse_id|
    joins(:verse_topics).where(verse_topics: {verse_id: verse_id})
  }

  scope :chapter_id_cont, lambda {|chapter_id|
    verses = Verse.order('verse_index ASC').where(chapter_id: chapter_id).select(:id)
    joins(:verse_topics).where(verse_topics: {verse_id: verses})
  }

  def self.ransackable_scopes(*)
    %i[verse_id_eq chapter_id_cont]
  end

  def self.roots
    where(parent_id: nil)
  end

  def ayah_keys
    verses.pluck(:verse_key)
  end

  def all_children
    Topic.where("parent_id = :id OR thematic_parent_id = :id OR ontology_parent_id = :id", id: id)
  end

  def get_parent
    parent || thematic_parent || ontology_parent
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
