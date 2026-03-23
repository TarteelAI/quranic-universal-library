require 'minitest/autorun'
require 'ostruct'
require 'active_support/inflector'

module ResourceSearchTestSupport
  FakeChapterRecord = Struct.new(:chapter_number, :name_simple, :name_complex, keyword_init: true)
  FakeVerseRecord = Struct.new(:chapter_id, :verse_number, :verse_key, :chapter, keyword_init: true)
  FakeTagRecord = Struct.new(:name, :slug, :description, keyword_init: true)

  class FakeResource < OpenStruct
    def get_tags
      downloadable_resource_tags
    end
  end

  unless Object.const_defined?(:Chapter)
    class ::Chapter
      class << self
        attr_accessor :records

        def select(*)
          records || []
        end

        def find_by(chapter_number:)
          (records || []).find { |chapter| chapter.chapter_number == chapter_number }
        end
      end
    end
  end

  unless Object.const_defined?(:Verse)
    class ::Verse
      class << self
        attr_accessor :records

        def includes(*)
          self
        end

        def find_by(chapter_id:, verse_number:)
          (records || []).find do |verse|
            verse.chapter_id == chapter_id && verse.verse_number == verse_number
          end
        end
      end
    end
  end

  unless Object.const_defined?(:ResourceContent)
    module ::ResourceContent
      module CardinalityType
        OneVerse = '1_ayah'
        OneWord = '1_word'
        OnePhrase = '1_phrase'
        NVerse = 'n_ayah'
        OneChapter = '1_chapter'
        OnePage = '1_page'
        OneJuz = '1_juz'
        OneRub = '1_rub'
        OneHizb = '1_hizb'
        OneRuku = '1_ruku'
        OneManzil = '1_manzil'
        Quran = 'quran'
      end
    end
  end

  def install_quran_fixture
    chapter_one = FakeChapterRecord.new(chapter_number: 1, name_simple: 'Al-Fatihah', name_complex: 'Al Fatiha')
    chapter_two = FakeChapterRecord.new(chapter_number: 2, name_simple: 'Al-Baqarah', name_complex: 'Al Baqarah')

    Chapter.records = [chapter_one, chapter_two]
    Verse.records = [
      FakeVerseRecord.new(chapter_id: 1, verse_number: 1, verse_key: '1:1', chapter: chapter_one),
      FakeVerseRecord.new(chapter_id: 2, verse_number: 255, verse_key: '2:255', chapter: chapter_two)
    ]
  end

  def build_resource(id:, name:, resource_type:, cardinality_type:, tags: [], info: nil, group_heading: nil)
    FakeResource.new(
      id: id,
      name: name,
      info: info,
      resource_type: resource_type,
      cardinality_type: cardinality_type,
      downloadable_resource_tags: tags,
      humanize_cardinality_type: cardinality_label(cardinality_type),
      group_heading: group_heading || resource_type.tr('-', ' ').split.map(&:capitalize).join(' ')
    )
  end

  def cardinality_label(cardinality_type)
    {
      ResourceContent::CardinalityType::OneVerse => 'Ayah by Ayah',
      ResourceContent::CardinalityType::OneWord => 'Word by word',
      ResourceContent::CardinalityType::OnePhrase => 'Phrase',
      ResourceContent::CardinalityType::NVerse => 'Multiple Ayahs',
      ResourceContent::CardinalityType::OneChapter => 'Surah by Surah',
      ResourceContent::CardinalityType::OnePage => 'Page by Page',
      ResourceContent::CardinalityType::Quran => 'Quran'
    }.fetch(cardinality_type, cardinality_type)
  end
end
