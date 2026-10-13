# == Schema Information
#
# Table name: word_differences
#
#  chapter_id     :integer          not null
#  groups         :jsonb            not null
#  missing        :string           default([]), is an Array
#  review         :jsonb            not null
#  status         :string           not null
#  written_joined :string           default([]), is an Array
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  word_id        :integer          not null, primary key
#
# Indexes
#
#  index_word_differences_on_chapter_id  (chapter_id)
#  index_word_differences_on_status      (status)
#
# A shared word where the seven printed riwayat disagree: different spellings
# (groups), riwayat that do not read it (missing), or a word boundary. Loaded
# from quran-text differences.json, plus the dotting variants of word-index.csv;
# riwayah slugs are QUL's (shubah -> shuba).
#
# review (jsonb, P6.3) records what a reviewer decided for the word's glosses:
#   { "decision" => "same_meaning" | "overridden", "note" => "...", "by" => email, "at" => iso8601 }
# nil decision = still in the queue. Overrides themselves are word_translations
# rows with a riwayah_id (RiwayahOverride), written by Qiraat::GlossOverride.
class WordDifference < QuranApiRecord
  self.primary_key = :word_id

  STATUSES = %w[alif_variant rasm_variant word_boundary partial dotting_variant].freeze
  DECISIONS = %w[same_meaning overridden].freeze

  belongs_to :word
  belongs_to :chapter

  validates :status, presence: true

  scope :in_chapter, ->(chapter) { where(chapter_id: chapter) }
  scope :missing_in, ->(slug) { where('? = ANY(missing)', slug) }
  scope :needs_review, -> { where("review->>'decision' IS NULL") }
  scope :decided, -> { where("review->>'decision' IS NOT NULL") }
  scope :meaning_may_differ, -> { where(status: MEANING_STATUSES) }

  def self.ransackable_associations(_auth_object = nil)
    %w[word chapter]
  end

  # Spelling groups as [[text, [riwayah slugs]], ...]
  def spelling_groups
    groups.map { |g| [g['text'], g['riwayahs']] }
  end

  # The spelling a riwayah reads, or nil when it does not read the word.
  def form_for(riwayah_slug)
    return nil if missing.include?(riwayah_slug)

    groups.find { |g| g['riwayahs'].include?(riwayah_slug) }&.dig('text')
  end

  MEANING_STATUSES = %w[rasm_variant word_boundary partial dotting_variant].freeze

  def meaning_may_differ?
    MEANING_STATUSES.include?(status)
  end

  def decision
    review['decision']
  end

  # Record the reviewer's decision for this word.
  def decide!(decision, by:, note: nil)
    raise ArgumentError, "unknown decision #{decision.inspect}" unless decision.nil? || DECISIONS.include?(decision)

    self.review = decision.nil? ? {} : { 'decision' => decision, 'note' => note.presence, 'by' => by.to_s, 'at' => Time.current.utc.iso8601 }.compact
    save!
  end

  # The riwayat of spelling group `index` that can carry an override: every
  # riwayah of the group but Hafs, whose gloss is the shared row itself.
  def override_riwayat(index)
    slugs = (groups[index] || {})['riwayahs'].to_a - ['hafs']
    Riwayah.where(slug: slugs).order(:id).to_a
  end
end
