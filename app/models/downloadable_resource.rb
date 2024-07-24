# == Schema Information
#
# Table name: downloadable_resources
#
#  id                  :bigint           not null, primary key
#  cardinality_type    :string
#  info                :text
#  name                :string
#  position            :integer          default(1)
#  published           :boolean          default(FALSE)
#  resource_type       :string
#  tags                :string
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  resource_content_id :integer
#
class DownloadableResource < ApplicationRecord
  belongs_to :language, optional: true
  belongs_to :resource_content, optional: true
  has_many :downloadable_files, dependent: :destroy

  scope :published, -> { where published: true }

  RESOURCE_TYPES = %w[quran-script audio translation tafsir mutashabihat similar-ayah surah-info mushaf-layout ayah-theme ayah-topics transliteration morphology quran].freeze

  def get_tags
    tags.to_s.split(',').compact_blank
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
    end
  end

  def group_heading
    case resource_type
    when 'quran-script'
      'Quran Script'
    when 'audio'
      'Audio'
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
      'Mushaf Layout'
    when 'ayah-theme'
      'Ayah Theme'
    when 'ayah-topics'
      'Ayah Topics'
    when 'transliteration'
      'Transliteration'
    when 'morphology'
      'Morphology and Grammar data'
    when 'quran'
      'Quran metadata'
    end
  end

  def icon
    case resource_type
    when 'quran-script'
      'fa-book-open'
    when 'audio'
      'fa-headphones-alt'
    when 'translation'
      'fa-language'
    when 'tafsir'
      'fa-book'
    when 'mutashabihat'
      'tags'
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
    when 'quran'
      'fa-book'
    else
      'fa-file'
    end
  end

  def group_name
    case resource_type
    when 'quran-script'
      'Quran Script'
    when 'audio'
      'Audio'
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
    when 'quran'
      'Quran metadata'
    end
  end

  def group_info
    case resource_type
    when 'script'
      'The Holy Quran in its original Arabic script'
    when 'audio'
      'Audio'
    when 'translation'
      'Translations of the Quran in various languages.'
    when 'tafsir'
      'Exegesis and interpretations of the Quran in various languages.'
    when 'mutashabihat'
      'Mutashabihat ul Quran data'
    when 'similar-ayah'
      'Similar Ayah data'
    when 'surah-info'
      '<h2>Surah Information Pack</h2> <p>This comprehensive resource includes detailed descriptions of each surah, including when they were revealed, their core themes, and key topics. It provides invaluable insights into the context and significance of the surahs, helping you to gain a deeper appreciation of the Quranic text.</p>'
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
    when 'quran'
      'Quran data, surahs, ayahs, words, juz etc.'
    end.html_safe
  end
end
