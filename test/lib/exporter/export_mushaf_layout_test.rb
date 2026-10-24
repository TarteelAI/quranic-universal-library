require 'minitest/autorun'
require 'json'
require 'fileutils'
require 'tmpdir'

# Pulls in String#to_param and String#parameterize, which BaseExporter#fix_file_name relies on.
require 'active_support/core_ext/object/to_param'
require 'active_support/core_ext/string/inflections'

require_relative '../../../lib/json_no_escape_html_state'

# Stub the ActiveRecord constants Exporter::ExportMushafLayout reaches for so the
# exporter can be loaded and exercised without booting Rails or hitting a database.
module MushafExporterTestSupport
  FakeResourceContent = Struct.new(:id, :resource, :sqlite_file_name, keyword_init: true)

  FakeMushaf = Struct.new(
    :id, :resource_content_id, :name, :pages_count, :lines_per_page,
    :default_font_name, :text_type_method,
    keyword_init: true
  )

  FakeWord = Struct.new(
    :word_index, :text_qpc_hafs, :text_uthmani, :code_v1,
    keyword_init: true
  )

  FakeMushafWord = Struct.new(:line_number, :position_in_page, :word, keyword_init: true)

  FakeAlignment = Struct.new(
    :mushaf_id, :page_number, :line_number,
    :center_aligned, :surah_name, :bismillah, :surah_number,
    keyword_init: true
  ) do
    def is_center_aligned? = center_aligned
    def is_surah_name?     = surah_name
    def is_bismillah?      = bismillah
    def get_surah_number   = surah_number
  end

  class FakeRelation
    include Enumerable

    def initialize(records)
      @records = records
    end

    def where(**conds)
      filtered = @records.select { |r| conds.all? { |k, v| r.public_send(k) == v } }
      self.class.new(filtered)
    end

    def includes(*) = self
    def order(*)    = self.class.new(@records)
    def first       = @records.first
    def each(&blk)  = @records.each(&blk)
  end

  class FakePage
    attr_reader :page_number

    def initialize(page_number:, mushaf_words: [])
      @page_number = page_number
      @mushaf_words = mushaf_words
    end

    # `page.words.includes(:word).order('position_in_page ASC').each`
    def words
      FakeRelation.new(@mushaf_words)
    end
  end

  unless Object.const_defined?(:Mushaf)
    class ::Mushaf
      class << self
        attr_accessor :records

        def find_by(**conds)
          (records || []).find { |r| conds.all? { |k, v| r.public_send(k) == v } }
        end
      end
    end
  end

  unless Object.const_defined?(:MushafPage)
    class ::MushafPage
      class << self
        attr_accessor :records_by_mushaf

        def where(mushaf_id:)
          MushafExporterTestSupport::FakeRelation.new(
            (records_by_mushaf || {}).fetch(mushaf_id, [])
          )
        end
      end
    end
  end

  unless Object.const_defined?(:MushafLineAlignment)
    class ::MushafLineAlignment
      class << self
        attr_accessor :records

        def where(**conds)
          MushafExporterTestSupport::FakeRelation.new(records || []).where(**conds)
        end
      end
    end
  end
end

require_relative '../../../lib/exporter/base_exporter'
require_relative '../../../lib/exporter/export_mushaf_layout'

class ExportMushafLayoutTest < Minitest::Test
  include MushafExporterTestSupport

  def setup
    @tmp_dir = Dir.mktmpdir('export-mushaf-layout-test')

    @mushaf = FakeMushaf.new(
      id: 5,
      resource_content_id: 42,
      name: 'KFGQPC Hafs',
      pages_count: 2,
      lines_per_page: 15,
      default_font_name: 'qpc-hafs',
      text_type_method: 'text_qpc_hafs'
    )

    @resource_content = FakeResourceContent.new(
      id: 42,
      resource: @mushaf,
      sqlite_file_name: 'kfgqpc-hafs-test'
    )

    install_default_pages_and_alignments

    Mushaf.records = [@mushaf]
  end

  def teardown
    FileUtils.remove_entry(@tmp_dir) if @tmp_dir && Dir.exist?(@tmp_dir)
    Mushaf.records = nil
    MushafPage.records_by_mushaf = nil
    MushafLineAlignment.records = nil
  end

  # Page 1 has: line 1 = surah name, line 2 = bismillah, line 3 = ayah (2 words).
  # Page 2 has: line 1 = ayah (3 words), unaligned (default justified ayah).
  def install_default_pages_and_alignments
    page1_words = [
      FakeMushafWord.new(line_number: 3, position_in_page: 1,
                         word: FakeWord.new(word_index: 1, text_qpc_hafs: 'بِسْمِ', code_v1: 'g1')),
      FakeMushafWord.new(line_number: 3, position_in_page: 2,
                         word: FakeWord.new(word_index: 2, text_qpc_hafs: 'ٱللَّهِ', code_v1: 'g2'))
    ]

    page2_words = [
      FakeMushafWord.new(line_number: 1, position_in_page: 1,
                         word: FakeWord.new(word_index: 3, text_qpc_hafs: 'ٱلرَّحْمَٰنِ', code_v1: 'g3')),
      FakeMushafWord.new(line_number: 1, position_in_page: 2,
                         word: FakeWord.new(word_index: 4, text_qpc_hafs: 'ٱلرَّحِيمِ', code_v1: 'g4')),
      FakeMushafWord.new(line_number: 1, position_in_page: 3,
                         word: FakeWord.new(word_index: 5, text_qpc_hafs: 'مَالِكِ', code_v1: 'g5'))
    ]

    MushafPage.records_by_mushaf = {
      5 => [
        FakePage.new(page_number: 1, mushaf_words: page1_words),
        FakePage.new(page_number: 2, mushaf_words: page2_words)
      ]
    }

    MushafLineAlignment.records = [
      FakeAlignment.new(mushaf_id: 5, page_number: 1, line_number: 1,
                        center_aligned: true, surah_name: true, bismillah: false, surah_number: 1),
      FakeAlignment.new(mushaf_id: 5, page_number: 1, line_number: 2,
                        center_aligned: true, surah_name: false, bismillah: true, surah_number: nil),
      FakeAlignment.new(mushaf_id: 5, page_number: 1, line_number: 3,
                        center_aligned: false, surah_name: false, bismillah: false, surah_number: nil)
      # Page 2 has no alignment rows on purpose, so the ayah falls back to justified.
    ]
  end

  def exporter
    Exporter::ExportMushafLayout.new(resource_content: @resource_content, base_path: @tmp_dir)
  end

  def export_and_read(file_name)
    base_path = exporter.export_json
    JSON.parse(File.read(File.join(base_path, file_name)))
  end

  def test_export_json_returns_the_json_directory
    base_path = exporter.export_json

    assert_equal File.join(@tmp_dir, 'kfgqpc-hafs-test', 'json'), base_path
    assert Dir.exist?(base_path)
  end

  def test_export_json_writes_info_file_with_mushaf_metadata
    info = export_and_read('info.json')

    assert_equal 'KFGQPC Hafs', info['name']
    assert_equal 2,            info['number_of_pages']
    assert_equal 15,           info['lines_per_page']
    assert_equal 'qpc-hafs',   info['font_name']
  end

  def test_export_json_writes_one_file_per_page
    base_path = exporter.export_json

    assert File.exist?(File.join(base_path, '1.json'))
    assert File.exist?(File.join(base_path, '2.json'))
  end

  def test_surah_name_line_carries_surah_number_and_is_centered
    page1 = export_and_read('1.json')
    line  = page1['lines']['1']

    assert_equal 'surah_name', line['type']
    assert_equal 'centered',   line['alignment']
    assert_equal 1,            line['surah_number']
    refute       line.key?('data')
    refute       line.key?('first_word_id')
  end

  def test_basmallah_line_is_centered_with_no_word_data
    line = export_and_read('1.json').dig('lines', '2')

    assert_equal 'basmallah', line['type']
    assert_equal 'centered',  line['alignment']
    refute       line.key?('data')
    refute       line.key?('surah_number')
  end

  def test_ayah_line_carries_word_text_index_range_and_alignment
    line = export_and_read('1.json').dig('lines', '3')

    assert_equal 'ayah',       line['type']
    assert_equal 'justified',  line['alignment']
    assert_equal 1,            line['first_word_id']
    assert_equal 2,            line['last_word_id']
    assert_equal ['بِسْمِ', 'ٱللَّهِ'], line['data']
  end

  def test_ayah_line_defaults_to_justified_when_no_alignment_row_exists
    line = export_and_read('2.json').dig('lines', '1')

    assert_equal 'ayah',      line['type']
    assert_equal 'justified', line['alignment']
    assert_equal 3,           line['first_word_id']
    assert_equal 5,           line['last_word_id']
    assert_equal ['ٱلرَّحْمَٰنِ', 'ٱلرَّحِيمِ', 'مَالِكِ'], line['data']
  end

  def test_ayah_word_text_uses_mushafs_text_type_method
    @mushaf.text_type_method = 'code_v1' # simulate a glyph-based v1 mushaf

    line = export_and_read('1.json').dig('lines', '3')

    assert_equal ['g1', 'g2'], line['data']
  end

  def test_words_are_sorted_by_word_index_even_if_inserted_out_of_order
    out_of_order = [
      FakeMushafWord.new(line_number: 3, position_in_page: 2,
                         word: FakeWord.new(word_index: 2, text_qpc_hafs: 'ٱللَّهِ')),
      FakeMushafWord.new(line_number: 3, position_in_page: 1,
                         word: FakeWord.new(word_index: 1, text_qpc_hafs: 'بِسْمِ'))
    ]
    MushafPage.records_by_mushaf[5][0] = FakePage.new(page_number: 1, mushaf_words: out_of_order)

    line = export_and_read('1.json').dig('lines', '3')

    assert_equal 1, line['first_word_id']
    assert_equal 2, line['last_word_id']
    assert_equal ['بِسْمِ', 'ٱللَّهِ'], line['data']
  end
end
