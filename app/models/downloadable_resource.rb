# == Schema Information
#
# Table name: downloadable_resources
#
#  id                  :bigint           not null, primary key
#  cardinality_type    :string
#  files_count         :integer          default(0)
#  info                :text
#  meta_data           :jsonb
#  name                :string
#  position            :integer          default(1)
#  published           :boolean          default(FALSE)
#  resource_type       :string
#  tags                :string
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  language_id         :integer
#  resource_content_id :integer
#
class DownloadableResource < ApplicationRecord
  include HasMetaData

  belongs_to :language, optional: true
  belongs_to :resource_content, optional: true
  has_many :downloadable_related_resources
  has_many :related_resources, through: :downloadable_related_resources, class_name: 'DownloadableResource'
  has_many :downloadable_files, dependent: :destroy

  has_many :downloadable_resource_taggings
  has_many :downloadable_resource_tags, through: :downloadable_resource_taggings

  accepts_nested_attributes_for :downloadable_resource_taggings, allow_destroy: true

  validates :name, :cardinality_type, :resource_type, :resource_content, presence: true

  scope :published, -> { where published: true }
  scope :quran_script, -> { where resource_type: 'quran-script' }

  RESOURCE_TYPES = %w[
    quran-script
    recitation
    translation
    tafsir
    mutashabihat
    similar-ayah
    surah-info
    mushaf-layout
    ayah-theme
    ayah-topics
    transliteration
    morphology
    quran-metadata
    font
  ].freeze

  delegate :one_ayah?, :one_word?, :chapter?, to: :resource_content
  validates :resource_content, uniqueness: { allow_nil: true }

  def tags=(val)
    names = val.split(',').map(&:strip).reject(&:empty?).uniq
    names.each do |tag_name|
      tag = DownloadableResourceTag.where('LOWER(name) = ?', tag_name.downcase).first_or_create(name: tag_name)
      downloadable_resource_taggings
        .where(
          downloadable_resource_tag_id: tag.id
        ).first_or_create
    end
  end

  def description
    info
  end

  def quran_script?
    resource_type == ResourceContent::SubType::QuranText
  end

  def font?
    resource_type == ResourceContent::SubType::Font
  end

  def surah_info?
    resource_type == 'surah-info'
  end

  def get_tags
    downloadable_resource_tags
  end

  def tag_names
    downloadable_resource_tags.pluck(:name)
  end

  def run_export_action
    attrs = {
      files_count: downloadable_files.count,
      published: published.nil? ? true : published
    }

    update_columns(attrs)
  end

  def refresh_export!(send_update_email = true)
    s = Exporter::DownloadableResources.new

    case resource_type
    when 'mushaf-layout'
      s.export_mushaf_layouts(resource_content: resource_content)
    when 'recitation'
      if one_ayah?
        s.export_ayah_recitation(resource_content: resource_content)
      elsif one_word?
        s.export_wbw_recitation
      elsif chapter?
        s.export_surah_recitation(resource_content: resource_content)
      end
    when 'translation'
      if one_ayah?
        s.export_ayah_translations(resource_content: resource_content)
      elsif one_word?
        s.export_word_translations(resource_content: resource_content)
      end
    when 'quran-script'
      if one_ayah?
        s.export_ayah_quran_script(resource_content: resource_content)
      elsif one_word?
        s.export_wbw_quran_script(resource_content: resource_content)
      end
    when 'tafsir'
      s.export_tafsirs(resource_content: resource_content)
    when 'mutashabihat'
      s.export_mutashabihat
    when 'similar-ayah'
      s.export_similar_ayah
    when 'surah-info'
      s.export_surah_info(language: resource_content.language)
    when 'mushaf-layout'
      s.export_mushaf_layouts(resource_content: resource_content)
    when 'ayah-theme'
      s.export_ayah_themes
    when 'ayah-topics'
      s.export_quran_topics
    when 'transliteration'
      if one_ayah?
        s.export_ayah_transliteration
      elsif one_word?
        s.export_word_transliteration
      end
    when 'morphology'
      s.export_quranic_morphology_data
    when 'quran-metadata'
      s.export_quran_metadata(resource_content: resource_content)
    when 'font'
      s.export_fonts(resource_content: resource_content)
    end

    notify_users if send_update_email
  end

  def humanize_cardinality_type
    case cardinality_type
    when ResourceContent::CardinalityType::OneVerse
      'Ayah by Ayah'
    when ResourceContent::CardinalityType::OneWord
      'Word by word'
    when ResourceContent::CardinalityType::NVerse
      'Multiple Ayahs'
    when ResourceContent::CardinalityType::OneChapter
      'Surah by Surah'
    when ResourceContent::CardinalityType::OneJuz
      'Juz info'
    when ResourceContent::CardinalityType::OnePage
      'Page by Page'
    when ResourceContent::CardinalityType::OneRub
      'Rub info'
    when ResourceContent::CardinalityType::OneManzil
      'Manzil info'
    when ResourceContent::CardinalityType::OneRuku
      'Ruku info'
    when ResourceContent::CardinalityType::OneHizb
      'Hizb info'
    when ResourceContent::CardinalityType::OnePhrase
      'Phrase'
    when ResourceContent::CardinalityType::Quran
      'Quran'
    when '1_sajda'
      'Sajda info'
    end
  end

  def group_heading
    case resource_type
    when 'quran-script'
      'Quran Script'
    when 'recitation'
      'Audio files and segments'
    when 'translation'
      'Translations'
    when 'tafsir'
      'Tafsir'
    when 'mutashabihat'
      'Mutashabihat ul Quran'
    when 'similar-ayah'
      'Similar Ayah'
    when 'surah-info'
      'Surah Info'
    when 'mushaf-layout'
      'Mushaf Layouts'
    when 'ayah-theme'
      'Ayah Theme'
    when 'ayah-topics'
      'Ayah Topics'
    when 'transliteration'
      'Transliteration'
    when 'morphology'
      'Quranic Morphology and Grammar data'
    when 'quran-metadata'
      'Quran metadata'
    when 'font'
      'Fonts'
    end
  end

  def sample_text

  end

  def humanize
    "#{name} - #{resource_type}(#{humanize_cardinality_type})"
  end

  def icon
    case resource_type
    when 'quran-script'
      'fa-font'
    when 'recitation'
      'fa-headphones-alt'
    when 'translation'
      'fa-language'
    when 'tafsir'
      'fa-book'
    when 'mutashabihat'
      'fa-tags'
    when 'similar-ayah'
      'fa-rectangle-list'
    when 'surah-info'
      'fa-book'
    when 'mushaf-layout'
      'fa-columns'
    when 'ayah-theme'
      'fa-book'
    when 'ayah-topics'
      'fa-book'
    when 'transliteration'
      'fa-language'
    when 'morphology'
      'fa-language'
    when 'quran-metadata'
      'fa-book'
    when 'font'
      'fa-font'
    else
      'fa-file'
    end
  end

  def group_name
    case resource_type
    when 'quran-script'
      'Quran Script'
    when 'recitation'
      'Audio files and segments'
    when 'translation'
      'Translation'
    when 'tafsir'
      'Tafsir'
    when 'mutashabihat'
      'Mutashabihat ul Quran'
    when 'similar-ayah'
      'Similar Ayah'
    when 'surah-info'
      'Surah Info'
    when 'mushaf-layout'
      'Mushaf Layout'
    when 'ayah-theme'
      'Ayah Theme'
    when 'ayah-topics'
      'Ayah Topics'
    when 'transliteration'
      'Transliteration'
    when 'morphology'
      'Morphology and Grammar data'
    when 'quran-metadata'
      'Quran metadata'
    when 'font'
      'Fonts'
    end
  end

  def group_info
    case resource_type
    when 'quran-script'
      'Ayah by ayah and word by text of Quran'
    when 'recitation'
      'Audio files and segments'
    when 'translation'
      'Ayah translations in various languages'
    when 'tafsir'
      'Tafsirs in various languages'
    when 'mutashabihat'
      'Mutashabihat ul Quran data'
    when 'similar-ayah'
      'Similar Ayah data'
    when 'surah-info'
      'Surah Information'
    when 'mushaf-layout'
      'Mushaf Layout data'
    when 'ayah-theme'
      'Ayah Theme'
    when 'ayah-topics'
      'Ayah Topics'
    when 'transliteration'
      'Transliteration'
    when 'morphology'
      'Morphology'
    when 'quran-metadata'
      'Quran data, surahs, ayahs, words, juz etc.'
    when 'font'
      "Quran fonts"
    end.html_safe
  end

  def mushaf_layout?
    resource_type == 'mushaf-layout'
  end

  def quran_script?
    resource_type == 'quran-script'
  end

  def notify_users
    downloads = UserDownload
                  .where(downloadable_file_id: downloadable_files.pluck(:id))
                  .includes(:user)

    notified = {}
    downloads.each do |user_download|
      next if notified[user_download.user_id]
      notified[user_download.user_id] = true

      DownloadableResourceMailer.new_update(self, user_download.user).deliver_later
    end
  end

  def restrict_download?
    !! meta_value('copyright')
  end
end
