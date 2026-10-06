# == Schema Information
#
# Table name: ayah_numberings
#
#  id                 :bigint           not null, primary key
#  basmalah_counted   :boolean
#  kind               :string           not null
#  meta_data          :jsonb            not null
#  name_ar            :string
#  name_en            :string
#  slug               :string           not null
#  source             :string
#  total_ayahs        :integer
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  counting_system_id :integer
#
# Indexes
#
#  index_ayah_numberings_on_counting_system_id  (counting_system_id)
#  index_ayah_numberings_on_slug                (slug) UNIQUE
#
# One concrete sequence of ayah ends. The Kufi numbering is included as a
# row (its ayahs coincide with the verses table) so every reader has one
# query path. A "printed" numbering belongs to one edition that deviates
# from its madhhab; a "madhhab" numbering is the school itself.
class AyahNumbering < QuranApiRecord
  KINDS = %w[madhhab printed].freeze

  belongs_to :counting_system, optional: true
  has_many :numbered_ayahs, foreign_key: :numbering_id, inverse_of: :numbering, dependent: :delete_all
  has_many :ayah_mappings, foreign_key: :numbering_id, dependent: :delete_all

  validates :slug, presence: true, uniqueness: true
  validates :kind, inclusion: { in: KINDS }

  def self.kufi
    find_by!(slug: 'kufi')
  end

  def kufi?
    slug == 'kufi'
  end

  def ayah(chapter_id, ayah_number)
    numbered_ayahs.find_by(chapter_id: chapter_id, ayah_number: ayah_number)
  end

  # Per-surah counted ayah totals, read from the rows (never hard-coded).
  def surah_counts
    numbered_ayahs.where(counted: true).group(:chapter_id).count
  end

  # The two tables every ayah-arithmetic helper needs, derived from the rows:
  # counted ayahs per surah (index 0 = surah 1) and the global index of each
  # surah's first ayah (1-based). Memoised per process; refreshed with reset_tables!.
  def surah_ayah_counts
    tables[:surah_ayah]
  end

  def first_ayah_indexes
    tables[:first_ayah]
  end

  def tables
    self.class.tables_cache[slug] ||= begin
      counts = numbered_ayahs.counted.joins(:chapter).group('chapters.chapter_number').count
      surah_ayah = (1..114).map { |n| counts.fetch(n, 0) }
      first = []
      running = 1
      surah_ayah.each { |c| first << running; running += c }
      { surah_ayah: surah_ayah.freeze, first_ayah: first.freeze, total: surah_ayah.sum }
    end
  end

  def self.tables_cache
    @tables_cache ||= {}
  end

  def self.reset_tables!
    @tables_cache = {}
  end

  def to_s
    name_en.presence || slug
  end
end
