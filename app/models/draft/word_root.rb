# A fix to the root, stem or lemma one word is linked to
class Draft::WordRoot < ApplicationRecord
  include PaperTrailAttribution

  LINKS = { 'root' => ::Root, 'stem' => ::Stem, 'lemma' => ::Lemma }.freeze
  HARAKAT = /[\u064B-\u065F\u0670\u06D6-\u06ED]/

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
    LINKS.keys.select { |link| new_text(link) || self["current_#{link}_id"] != self["draft_#{link}_id"] }
  end

  # A root, stem or lemma the user couldn't find, it's added when the draft is approved
  def new_text(link)
    meta_data.to_h["new_#{link}"].presence
  end

  def self.valid_new_text?(link, text)
    letters = text.remove(/\s/)
    return false if letters.match?(/[^\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF]/)

    link == 'root' ? (2..5).cover?(letters.remove(HARAKAT).size) && letters == letters.remove(HARAKAT) : letters.present?
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

    attribute_versions_to(user) do
      changes.each do |link|
        self["draft_#{link}_id"] = (LINKS[link].find_by_text(new_text(link)) || add_missing(link)).id if new_text(link)
      end
      changes.each { |link| word["#{link}_id"] = self["draft_#{link}_id"] }
      word.save(validate: false)
    end
    changes.flat_map { |link| [linked(link, 'current'), linked(link, 'draft')] }.compact.uniq.each(&:update_stats)

    update_columns(imported: true, draft_root_id: draft_root_id, draft_stem_id: draft_stem_id, draft_lemma_id: draft_lemma_id)

    word
  end

  private

  def links_text(side)
    changed_links.map do |link|
      text = side == 'draft' && new_text(link) ? "#{new_text(link)} (missing, will be added)" : self.class.label(linked(link, side))
      "#{link} #{text || 'none'}"
    end.join(', ')
  end

  def add_missing(link)
    text = new_text(link)
    clean = text.remove(HARAKAT).remove(/\s/)

    case link
    when 'root'
      letters = clean.chars.join(' ')
      ::Root.create!(arabic_trilateral: letters, value: letters, text_clean: letters, english_trilateral: '')
    when 'stem'
      ::Stem.create!(text_madani: text, text_clean: clean)
    when 'lemma'
      ::Lemma.create!(text_madani: text, text_clean: clean, en_translations: [])
    end
  end
end
