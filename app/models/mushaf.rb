# == Schema Information
#
# Table name: mushafs
#
#  id                  :bigint           not null, primary key
#  default_font_name   :string
#  description         :text
#  enabled             :boolean
#  is_default          :boolean          default(FALSE)
#  lines_per_page      :integer
#  name                :string           not null
#  pages_count         :integer
#  qirat_type_id       :integer
#  resource_content_id :integer
#
# Indexes
#
#  index_mushafs_on_enabled        (enabled)
#  index_mushafs_on_is_default     (is_default)
#  index_mushafs_on_qirat_type_id  (qirat_type_id)
#

class Mushaf < QuranApiRecord
  include Resourceable

  belongs_to :qirat_type
  has_many :mushaf_pages

  validates :pages_count, presence: true, numericality: { greater_than: 100 }
  after_create :attach_resource_content
  after_create :generate_pages
  scope :approved, -> { where(enabled: true) }

  def using_glyphs?
    [1, 2].include?(id)
  end

  def lines_count
    mushaf_pages.sum(:lines_count)
  end

  def humanize
    "#{id}- #{name} - Pages #{pages_count} - Lines #{lines_per_page}"
  end

  def percentage_done
    total = Word.count
    done = MushafWord.where(mushaf_id: id).count

    ((done.to_f / total.to_f) * 100.to_f).round 2
  end

  def done_pages_count
    MushafPage.where(mushaf_id: id).where.not(first_word_id: nil, last_word_id: nil).count
  end

  def font_code
    default_font_name
  end

  def use_images?
    default_font_name == 'img'
  end

  def pdf_url
    #TODO: Naveed. Add this in db
    #TODO: more mushaf layouts we can add
    # - https://tafsir.app/m-qatar/1/1
    #
    case id
    when 1 # v2
      "https://tafsir.app/m-madinah/1/1"
    when 2
      "https://tafsir.app/m-madinah-old/1/1"
    when 3 # Indopak
    when 4 # Uthmani text
    when 5 # KFQPC Hafs text
      "https://download.qurancomplex.gov.sa/resources_dev/UthmanicHafs_v18.zip"
    when 6 # Indopak 15 lines
      "https://archive.org/details/AlQuran15LinesQudratullah/page/n609/mode/2up"
    when 7 # Indopak 16 lines
      "https://archive.org/details/AlQuranAlKareem16LinesTajCompany/page/n517/mode/2up"
    end
  end

  def text_type_method
    mushaf_name = name.to_s.downcase

    if mushaf_name.include?('indopak')
      'text_indopak_nastaleeq'
    elsif mushaf_name.include?('v1')
      'code_v1'
    elsif mushaf_name.include?('v2') || default_font_name.include?('v4-tajweed')
      'code_v2'
    elsif mushaf_name.include?('uthmani')
      'text_uthmani'
    else
      'text_qpc_hafs'
    end
  end

  def create_resource
    if resource_content.nil?
      create_resource_content(
        name: name,
        approved: enabled?,
        sub_type: ResourceContent::SubType::Data,
        cardinality_type: ResourceContent::CardinalityType::OneWord,
        resource_type_name: ResourceContent::ResourceType::Quran
      )
    end
  end

  def update_pages_stats
    mushaf_pages.each do |page|
      page = MushafPage.where(mushaf_id: id, page_number: page.page_number).first_or_initialize

      first_word = MushafWord.where(page_number: page.page_number, mushaf_id: id).order("position_in_page ASC").first
      last_word = MushafWord.where(page_number: page.page_number, mushaf_id: id).order("position_in_page DESC").first

      verses = Verse.order("verse_index ASC").where("verse_index >= #{first_word.word.verse_id} AND verse_index <= #{last_word.word.verse_id}")
      page.first_verse_id = first_word.word.verse_id
      page.last_verse_id = last_word.word.verse_id
      page.verses_count = verses.size
      page.first_word_id = first_word.word_id
      page.last_word_id = last_word.word_id

      map = {}

      verses.each do |verse|
        if map[verse.chapter_id]
          next
        end

        chapter_verses = verses.where(chapter_id: verse.chapter_id)
        map[verse.chapter_id] = "#{chapter_verses.first.verse_number}-#{chapter_verses.last.verse_number}"
      end

      page.verses_count = verses.size

      page.verse_mapping = map
      page.save
    end
  end

  def update_surah_numbers_in_layout
    surah = 1
    pages = MushafLineAlignment.where(mushaf_id: id).pluck(:page_number).uniq.sort
    pages.each do |page_number|
      lines = MushafLineAlignment.where(mushaf_id: id, page_number: page_number).order('line_number ASC')

      lines.each do |line|
        if line.is_surah_name?
          line.set_meta_value('surah_number', surah)
          surah += 1
          line.save
        end
      end
    end
  end

  protected

  def attach_resource_content
    resource_content || create_resource
  end

  def generate_pages
    1.upto(pages_count) do |num|
      page = mushaf_pages.where(page_number: num).first_or_initialize
      page.save(validate: false)
    end
  end
end

