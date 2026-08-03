require_relative '../../../test_helper'
require_relative '../../../../app/services/morphology/noor_bayan/csv_reader'
require 'tempfile'

class NoorBayanCsvReaderTest < Minitest::Test
  def test_reads_utf16_tab_separated_file
    content = "tid\tuthmani_token\tpos\n1\tبِ\tP\n2\tسْمِ\tN\n"
    file = Tempfile.new(['noor_bayan', '.csv'])
    file.binmode
    file.write "\xFF\xFE".b
    file.write content.encode(Encoding::UTF_16LE).force_encoding(Encoding::BINARY)
    file.close

    rows = []
    Morphology::NoorBayan::CsvReader.new(file.path).each_row { |row| rows << row }

    assert_equal 2, rows.size
    assert_equal({ 'tid' => '1', 'uthmani_token' => 'بِ', 'pos' => 'P' }, rows.first)
    assert_equal 'سْمِ', rows.last['uthmani_token']
  ensure
    file.unlink
  end
end
