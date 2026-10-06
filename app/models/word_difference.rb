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
# from quran-text differences.json; riwayah slugs are QUL's (shubah -> shuba).
class WordDifference < QuranApiRecord
  self.primary_key = :word_id

  STATUSES = %w[alif_variant rasm_variant word_boundary partial].freeze

  belongs_to :word
  belongs_to :chapter

  validates :status, presence: true

  scope :in_chapter, ->(chapter) { where(chapter_id: chapter) }
  scope :missing_in, ->(slug) { where('? = ANY(missing)', slug) }
  scope :needs_review, -> { where("review->>'decision' IS NULL") }

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

  def meaning_may_differ?
    %w[rasm_variant word_boundary partial].include?(status)
  end
end
