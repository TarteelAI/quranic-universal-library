# == Schema Information
#
# Table name: scripts
#
#  id                       :bigint           not null, primary key
#  column_name              :string
#  enabled                  :boolean          default(TRUE), not null
#  font_css_class           :string
#  font_family              :string
#  font_file_url            :string
#  kind                     :string           default("unicode"), not null
#  licence                  :string
#  meta_data                :jsonb            not null
#  name                     :string           not null
#  release_year             :integer
#  slug                     :string           not null
#  source_package           :string
#  source_sha256            :string
#  storage                  :string           default("rows"), not null
#  text_sha256              :string
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  ayah_resource_content_id :integer
#  riwayah_id               :integer
#  word_resource_content_id :integer
#
# Indexes
#
#  index_scripts_on_column_name  (column_name)
#  index_scripts_on_riwayah_id   (riwayah_id)
#  index_scripts_on_slug         (slug) UNIQUE
#
# One riwayah in one typeface or encoding. `storage` says where the text
# lives: "column" (a column on words/verses, every Hafs script today),
# "rows" (word_texts / ayah_texts, the quran-text imports, P3.3) or "legacy"
# (quran_script_by_* keyed by the riwayah's own numbering, P3.7).
class Script < QuranApiRecord
  KINDS = %w[unicode glyph image].freeze
  STORAGES = %w[column rows legacy].freeze

  belongs_to :riwayah
  belongs_to :word_resource_content, class_name: 'ResourceContent', optional: true
  belongs_to :ayah_resource_content, class_name: 'ResourceContent', optional: true
  has_many :mushafs, dependent: :nullify

  validates :slug, presence: true, uniqueness: true
  validates :name, presence: true
  validates :kind, inclusion: { in: KINDS }
  validates :storage, inclusion: { in: STORAGES }
  validates :column_name, presence: true, if: -> { storage == 'column' }

  scope :enabled, -> { where(enabled: true) }
  scope :column_backed, -> { where(storage: 'column') }
  scope :row_backed, -> { where(storage: 'rows') }
  scope :for_riwayah, ->(riwayah) { where(riwayah_id: riwayah) }

  def self.find_by_column(column_name)
    column_backed.find_by(column_name: column_name.to_s)
  end

  def column?
    storage == 'column'
  end

  def rows?
    storage == 'rows'
  end

  def legacy?
    storage == 'legacy'
  end

  def glyph?
    kind == 'glyph'
  end

  def image?
    kind == 'image'
  end

  # CSS class for a word of this script. Glyph scripts use one font per page:
  # meta_data['css_pattern'] like "p{page}-v2" with the page read from
  # meta_data['page_column'] on the word.
  def css_class_for(word = nil)
    return font_css_class unless glyph? && word

    page = word.public_send(meta_data['page_column'] || 'page_number')
    (meta_data['css_pattern'] || font_css_class).to_s.sub('{page}', page.to_s)
  end

  def to_s
    name
  end
end
