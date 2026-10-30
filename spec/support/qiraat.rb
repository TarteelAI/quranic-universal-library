# frozen_string_literal: true

require 'json'
require 'csv'

# Loads the fixture slice in spec/fixtures/qiraat into the Quran test database
# and gives specs typed access to the upstream reference files.
#
#   QiraatFixtures.load!                 # once per suite (see rails_helper)
#   QiraatFixtures.word_index            # Array<Hash> rows of word-index.csv
#   QiraatFixtures.ayah_map['ayahs']     # quran-text ayah-map entries
#   QiraatFixtures.qiraat                # qiraat-ayah-map data/qiraat.json
module QiraatFixtures
  DIR = Rails.root.join('spec', 'fixtures', 'qiraat')

  # Insertion order respects foreign keys where they exist (tajweed_words etc.
  # are not in the slice). Each model is cleared, then inserted with its
  # original ids, and the id sequence is moved past the highest id.
  QUL_TABLES = [
    ['chapters', -> { Chapter }],
    ['verses', -> { Verse }],
    ['words', -> { Word }],
    ['mushafs', -> { Mushaf }],
    ['mushaf_pages', -> { MushafPage }],
    ['mushaf_words', -> { MushafWord }]
  ].freeze

  module_function

  def load!
    raise "refusing to load fixtures into #{Verse.connection.current_database}" unless Verse.connection.current_database == 'quran_test'

    QUL_TABLES.each do |name, model_ref|
      model = model_ref.call
      rows = JSON.parse(DIR.join('qul', "#{name}.json").read)
      model.unscoped.delete_all
      next if rows.empty?

      model.insert_all(rows, record_timestamps: false)
      reset_sequence(model)
    end
  end

  def reset_sequence(model)
    conn = model.connection
    seq = conn.select_value("SELECT pg_get_serial_sequence('#{model.table_name}', 'id')")
    return unless seq

    conn.execute("SELECT setval('#{seq}', COALESCE((SELECT MAX(id) FROM #{model.quoted_table_name}), 1))")
  end

  def upstream(name)
    DIR.join('upstream', name)
  end

  def word_index
    @word_index ||= CSV.read(upstream('word-index.csv'), headers: true).map(&:to_h)
  end

  def word_index_by_number
    @word_index_by_number ||= word_index.index_by { |r| r['number'].to_i }
  end

  def ayah_map
    @ayah_map ||= JSON.parse(upstream('ayah-map.json').read)
  end

  def differences
    @differences ||= JSON.parse(upstream('differences.json').read)
  end

  def counting
    @counting ||= JSON.parse(upstream('counting.json').read)
  end

  def catalog
    @catalog ||= JSON.parse(upstream('catalog.json').read)
  end

  def qiraat
    @qiraat ||= JSON.parse(upstream('qiraat.json').read)
  end

  def counting_systems
    @counting_systems ||= JSON.parse(upstream('counting-systems.json').read)
  end

  def printed_editions
    @printed_editions ||= JSON.parse(upstream('printed-editions.json').read)
  end
end
