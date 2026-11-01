# A fix to the root, stem or lemma one word is linked to
class Draft::WordRoot < ApplicationRecord
  include PaperTrailAttribution

  LINKS = { 'root' => ::Root, 'stem' => ::Stem, 'lemma' => ::Lemma }.freeze

  belongs_to :word, class_name: '::Word'
  belongs_to :verse
  belongs_to :user, optional: true

  # Fixes suggested by users that aren't approved yet
  scope :pending_contributions, -> { where.not(user_id: nil).where(imported: false) }

  before_save { self.text_matched = matches_current? }

  # A draft that changes some links of a word, e.g. for_word(word, user, comment, 'lemma' => nil)
  def self.for_word(word, user, comment, changes)
    draft = new(word: word, verse_id: word.verse_id, user: user, location: word.location, comment: comment.to_s.strip.presence)
    LINKS.each_key do |link|
      draft["current_#{link}_id"] = word["#{link}_id"]
      draft["draft_#{link}_id"] = changes.key?(link) ? changes[link] : word["#{link}_id"]
    end
    draft
  end

  def changed_links
    LINKS.keys.reject { |link| self["current_#{link}_id"] == self["draft_#{link}_id"] }
  end

  def matches_current?
    changed_links.empty?
  end

  # "root ر ح م, lemma رَحْمَة" for the pending suggestions banner
  def current_text
    links_text('current')
  end

  def draft_text
    links_text('draft')
  end

  def linked(link, side)
    id = self["#{side}_#{link}_id"]
    LINKS[link].find_by(id: id) if id
  end

  def self.label(record)
    case record
    when ::Root then record.arabic_trilateral
    when ::Stem, ::Lemma then record.text_madani
    end
  end

  def status
    if imported?
      'imported'
    elsif need_review?
      'needs review'
    else
      'approved'
    end
  end

  def import!
    changes = changed_links
    affected = changes.flat_map { |link| [linked(link, 'current'), linked(link, 'draft')] }.compact
    changes.each { |link| word["#{link}_id"] = self["draft_#{link}_id"] }

    attribute_versions_to(user) do
      word.save(validate: false)
    end
    affected.each(&:update_stats)

    update_columns(imported: true)

    word
  end

  private

  def links_text(side)
    changed_links.map { |link| "#{link} #{self.class.label(linked(link, side)) || 'none'}" }.join(', ')
  end
end
