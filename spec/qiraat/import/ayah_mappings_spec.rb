# frozen_string_literal: true

require 'rails_helper'
require 'tempfile'

RSpec.describe 'P4.3 printed numberings, ayah mappings and ayah texts' do
  let(:counting) { QiraatFixtures.upstream('counting.json') }
  let(:catalog) { QiraatFixtures.upstream('catalog.json') }

  before do
    AyahMapping.delete_all
    AyahText.delete_all
    NumberedAyah.delete_all
    AyahNumbering.delete_all
    Riwayah.update_all(default_numbering_id: nil)
    Qiraat::Backfill::WordNumbers.new(csv_path: QiraatFixtures.upstream('word-index.csv'), dry_run: false, logger: nil).call
    Qiraat::Import::Numberings.new(counting_path: counting, catalog_path: catalog, systems: %w[kufi madani-last], surahs: [1]).call
  end

  describe Qiraat::Import::AyahMappings do
    before { described_class.new.call }

    let(:ml) { AyahNumbering.find_by!(slug: 'madani-last') }

    def mapping(key)
      AyahMapping.find_by!(numbering_id: ml.id, verse_id: Verse.find_by!(verse_key: key).id)
    end

    it 'maps the Fatihah basmalah to ayah 0 as unnumbered' do
      m = mapping('1:1')
      expect(m.relation).to eq('unnumbered')
      expect(m.ayah.ayah_number).to eq(0)
      expect(m.ayahs.size).to eq(1)
    end

    it 'maps a renumbered ayah one to one as same' do
      m = mapping('1:2')
      expect(m.relation).to eq('same')
      expect(m.ayah.ayah_key).to eq('1:1')
      expect(m).not_to be_split
    end

    it 'maps the split verse 1:7 to the ayah range 1:6-1:7' do
      m = mapping('1:7')
      expect(m).to be_split
      expect(m.ayahs.map(&:ayah_key)).to eq(%w[1:6 1:7])
      expect(m.merges_with_next).to be(false)
    end

    it 'maps Kufi onto itself' do
      k = AyahNumbering.kufi
      m = AyahMapping.find_by!(numbering_id: k.id, verse_id: Verse.find_by!(verse_key: '1:7').id)
      expect(m.ayah_id).to eq(Verse.find_by!(verse_key: '1:7').id)
      expect(m.relation).to eq('same')
    end

    it 'is idempotent' do
      before_rows = AyahMapping.where(numbering_id: ml.id).order(:verse_id).pluck(:verse_id, :ayah_id, :relation)
      described_class.new.call
      expect(AyahMapping.where(numbering_id: ml.id).order(:verse_id).pluck(:verse_id, :ayah_id, :relation)).to eq(before_rows)
    end
  end

  describe Qiraat::Import::PrintedNumberings do
    # Fatihah-only edition files: Warsh exactly on the madhhab; a Susi-like
    # file whose last ayah end moves one word earlier so it deviates.
    def edition_file(key, system:, ayah_starts:)
      rows = QiraatFixtures.word_index.select { |r| r['surah'] == '1' }.sort_by { |r| r['number'].to_i }
      data = {
        'mushaf' => { 'key' => key, 'name_en' => key.capitalize, 'name_ar' => key, 'word_count' => rows.size },
        'counting' => { 'system' => system, 'system_printed' => system, 'ayah_count' => ayah_starts.size, 'basmalah_counted' => false, 'khilaf' => [] },
        'provenance' => { 'text' => { 'package' => "Uthmanic#{key.capitalize}-v-3.0.zip", 'release_year' => 2026 } },
        'words' => rows.map { |r| r["form_#{key}"] },
        'numbering' => { 'total' => 77_434, 'missing' => [], 'written_joined' => [] },
        'ayah_starts' => ayah_starts
      }
      dir = Dir.mktmpdir
      File.write(File.join(dir, "#{key}.json"), JSON.generate(data))
      dir
    end

    it 'uses the madhhab as default when the printed ends equal it, and builds a printed numbering when they deviate' do
      madhhab_ends = QiraatFixtures.counting['systems']['madani-last']['ayah_ends'].select { |n| n <= 29 }
      # surah 1 has numbers 1..29 at positions 0..28, so an ayah ending at number e starts the next at position e
      starts = [4] + madhhab_ends[0..-2]
      warsh_dir = edition_file('warsh', system: 'madani-last', ayah_starts: starts)
      report = described_class.new(mushaf_dir: warsh_dir, counting_path: counting, catalog_path: catalog, editions: ['warsh']).call
      expect(report[:editions]['warsh'][:deviates]).to be(false)
      expect(Riwayah.find_by!(slug: 'warsh').default_numbering.slug).to eq('madani-last')
      expect(madhhab_ends.size).to eq(7)

      # a susi-like edition whose 1:7 starts one word later than the madhhab (the end of 1:6 moves one number up)
      shifted = starts.dup
      shifted[-1] += 1
      susi_dir = edition_file('susi', system: 'madani-last', ayah_starts: shifted)
      report = described_class.new(mushaf_dir: susi_dir, counting_path: counting, catalog_path: catalog, editions: ['susi']).call
      expect(report[:editions]['susi'][:deviates]).to be(true)
      expect(report[:editions]['susi'][:distance]).to eq(2) # one end removed, one added
      printed = Riwayah.find_by!(slug: 'susi').default_numbering
      expect(printed.kind).to eq('printed')
      expect(printed.slug).to eq('kfgqpc-susi-v3.0')
      expect(printed.numbered_ayahs.counted.count).to eq(7)
      expect(printed.ayah(1, 6).last_number).to eq(madhhab_ends[-2] + 1)
      expect(printed.counting_system.slug).to eq('madani-last')
    end

    it 'gives riwayat without an edition the madhhab attributed to their qari' do
      described_class.new(mushaf_dir: Dir.mktmpdir, counting_path: counting, catalog_path: catalog, editions: []).call
      expect(Riwayah.find_by!(slug: 'khallad').default_numbering.slug).to eq('kufi')
      expect(Riwayah.find_by!(slug: 'khallad').meta_data['default_numbering_attributed']).to be(true)
      expect(Riwayah.find_by!(slug: 'qunbul').default_numbering).to be_nil # makki not built in this spec
    end
  end

  describe Qiraat::Import::AyahTexts do
    it 'joins word_texts per ayah of the default numbering, basmalah row included' do
      warsh = Riwayah.find_by!(slug: 'warsh')
      warsh.update!(default_numbering: AyahNumbering.find_by!(slug: 'madani-last'))
      script = Script.find_by!(slug: 'qpc-warsh')
      rows = Verse.find_by!(verse_key: '1:1').words.where(char_type_name: 'word').map { |w| { script_id: script.id, word_id: w.id, text: "b#{w.position}", marks: [] } }
      rows += Verse.find_by!(verse_key: '1:2').words.where(char_type_name: 'word').map.with_index { |w, i| { script_id: script.id, word_id: w.id, text: "h#{w.position}", marks: (i.zero? ? ['۞'] : []) } }
      WordText.where(script_id: script.id).delete_all
      WordText.upsert_all(rows, unique_by: %i[script_id word_id])
      report = described_class.new(scripts: ['qpc-warsh']).call
      ml = AyahNumbering.find_by!(slug: 'madani-last')
      expect(report['qpc-warsh'][:numbering]).to eq('madani-last')
      expect(AyahText.find_by!(script_id: script.id, ayah_id: ml.ayah(1, 0).id).text).to eq('b1 b2 b3 b4')
      expect(AyahText.find_by!(script_id: script.id, ayah_id: ml.ayah(1, 1).id).text).to eq('۞ h1 h2 h3 h4')
      expect(ml.ayah(1, 1).text_for(script)).to eq('۞ h1 h2 h3 h4')
      expect(AyahText.where(script_id: script.id).count).to eq(2) # ayahs without forms are not written
    end
  end
end
