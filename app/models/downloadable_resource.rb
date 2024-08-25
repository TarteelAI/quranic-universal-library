# == Schema Information
#
# Table name: downloadable_resources
#
#  id                  :bigint           not null, primary key
#  cardinality_type    :string
#  files_count         :integer          default(0)
#  info                :text
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
  belongs_to :language, optional: true
  belongs_to :resource_content, optional: true
  has_many :downloadable_files, dependent: :destroy

  scope :published, -> { where published: true }

  RESOURCE_TYPES = %w[quran-script recitation translation tafsir mutashabihat similar-ayah surah-info mushaf-layout ayah-theme ayah-topics transliteration morphology quran-metadata].freeze

  delegate :one_ayah?, :one_word?, :chapter?, to: :resource_content

  def get_tags
    tags.to_s.split(',').compact_blank
  end

  def run_export_action
    attrs  = {
      files_count: downloadable_files.count,
      published: published.nil? ? true : published
    }

    update_columns(attrs)
  end

  def refresh_export!
    s = Exporter::DownloadableResources.new

    case resource_type
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
    when 'mutashabihat'
    when 'similar-ayah'
    when 'surah-info'
    when 'mushaf-layout'
    when 'ayah-theme'
    when 'ayah-topics'
    when 'transliteration'
    when 'morphology'
    when 'quran-metadata'
    end
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
    end
  end

  def sample_text

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
    end
  end

  def group_info
    case resource_type
    when 'quran-script'
      'Ayah by ayah and word by text of Quran'
    when 'recitation'
      'Audio files and segments'
    when 'translation'
      'Ayah translations in various languages.'
    when 'tafsir'
      'Exegesis and interpretations of the Quran in various languages.'
    when 'mutashabihat'
      'Mutashabihat ul Quran data'
    when 'similar-ayah'
      'Similar Ayah data'
    when 'surah-info'
      #  '<h2>Surah Information Pack</h2> <p>This comprehensive resource includes detailed descriptions of each surah, including when they were revealed, their core themes, and key topics. It provides invaluable insights into the context and significance of the surahs, helping you to gain a deeper appreciation of the Quranic text.</p>'
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
    end.html_safe
  end
end
