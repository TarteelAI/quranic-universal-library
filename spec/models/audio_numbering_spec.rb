# frozen_string_literal: true

require 'rails_helper'

# P7.3: recitations carry the numbering of their riwayah; segments and
# ayah audio files carry the numbered ayah and word timings by shared
# number. A dev-only Warsh recitation over al-Fatihah saves its segments
# against Warsh keys (1:1 = Kufi 1:2 … 1:3 = Kufi 1:4); a Hafs recitation
# keeps the Kufi keys and gets ayah_id = verse_id.
RSpec.describe 'audio numbering (P7.3)' do
  let(:warsh) { Riwayah.find_by!(slug: 'warsh') }
  let(:hafs) { Riwayah.hafs }
  let(:madani_last) { AyahNumbering.find_by!(slug: 'madani-last') }

  before do
    AyahMapping.delete_all
    NumberedAyah.delete_all
    AyahNumbering.delete_all
    Qiraat::Backfill::WordNumbers.new(csv_path: QiraatFixtures.upstream('word-index.csv'), dry_run: false, logger: nil).call
    Qiraat::Import::Numberings.new(counting_path: QiraatFixtures.upstream('counting.json'), catalog_path: QiraatFixtures.upstream('catalog.json'), systems: %w[kufi madani-last], surahs: [1, 2]).call
    Qiraat::Import::AyahMappings.new.call
    warsh.update!(default_numbering: madani_last)
    hafs.update!(default_numbering: AyahNumbering.kufi)
  end

  def gapless(riwayah)
    Audio::Recitation.new(name: "spec #{riwayah.slug}", riwayah: riwayah, relative_path: 'spec', format: 'mp3').tap { |r| r.save!(validate: false) }
  end

  def chapter_file(rec, chapter_id = 1)
    Audio::ChapterAudioFile.new(audio_recitation: rec, chapter_id: chapter_id, audio_url: 'spec.mp3', format: 'mp3').tap { |f| f.save!(validate: false) }
  end

  it 'defaults the numbering from the riwayah and counts ayahs from it' do
    w = gapless(warsh)
    h = gapless(hafs)
    expect(w.numbering_or_default).to eq(madani_last)
    expect(h.numbering_or_default).to be_kufi
    expect(w.expected_ayahs_count(Chapter.find(1))).to eq(7)
    expect(h.expected_ayahs_count(Chapter.find(1))).to eq(7)
    expect(w.expected_ayahs_count(Chapter.find(2))).to eq(madani_last.numbered_ayahs.where(chapter_id: 2, counted: true).count)
    expect(w.expected_ayahs_count).to eq(madani_last.total_ayahs)
    expect(w.resolver.numbering).to eq(madani_last)
    expect(w.ayah_for_key('1:3').kufi_verses.map(&:verse_key)).to eq(['1:4'])
  end

  it 'saves a Warsh segment against the Warsh key, anchored on the first Kufi verse, with timings by shared number' do
    rec = gapless(warsh)
    file = chapter_file(rec)
    %w[1:1 1:2 1:3].each_with_index do |key, i|
      ayah = rec.ayah_for_key(key)
      seg = Audio::Segment.new(audio_recitation: rec, audio_file: file)
      seg.set_ayah(ayah)
      seg.set_timing(i * 1000, i * 1000 + 900, seg.verse)
      seg.set_segments!([[1, i * 1000, i * 1000 + 300], [2, i * 1000 + 300, i * 1000 + 900]])
    end
    rows = file.audio_segments.order(:verse_number)
    expect(rows.map(&:verse_key)).to eq(%w[1:1 1:2 1:3])
    expect(rows.map { |s| s.verse.verse_key }).to eq(%w[1:2 1:3 1:4]) # Warsh does not count the basmalah
    expect(rows.map { |s| s.ayah.ayah_key }).to eq(%w[1:1 1:2 1:3])
    expect(rows.map(&:ayah_id)).to eq(rows.map { |s| s.ayah.id })
    malik = rows.last
    expect(malik.number_segments.map(&:first)).to eq(Word.where(location: %w[1:4:1 1:4:2]).order(:position).pluck(:number))
    expect(malik.segments.map(&:first)).to eq([1, 2])
    # one row per ayah of the numbering: the partial unique index on (audio_file_id, ayah_id)
    dup = Audio::Segment.new(audio_recitation: rec, audio_file: file).set_ayah(rec.ayah_for_key('1:3'))
    dup.set_timing(0, 1, dup.verse)
    dup.verse_number = 99 # dodge the old (audio_file_id, verse_number) index to prove the new one fires
    expect { dup.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it 'keeps a Hafs recitation on Kufi keys with ayah_id equal to the verse id' do
    rec = gapless(hafs)
    file = chapter_file(rec)
    verse = Verse.find_by!(verse_key: '1:4')
    seg = Audio::Segment.new(audio_recitation: rec, audio_file: file, verse: verse)
    seg.set_timing(0, 900, verse)
    seg.set_segments!([[1, 0, 400], [2, 400, 900]])
    expect([seg.verse_key, seg.verse_number, seg.ayah_id]).to eq(['1:4', 4, verse.id])
    expect(seg.number_segments).to eq([[Word.find_by!(location: '1:4:1').number, 0, 400], [Word.find_by!(location: '1:4:2').number, 400, 900]])
    expect(Audio::Segment.number_segments_for([[1, 0, 1], [7, 1, 2]], { 1 => 11 })).to eq([[11, 0, 1]]) # unknown positions drop
  end

  it 'keys ayah-by-ayah files the same way' do
    rec = Recitation.new(reciter_name: 'spec', riwayah: hafs, relative_path: 'spec').tap { |r| r.save!(validate: false) }
    verse = Verse.find_by!(verse_key: '1:4')
    audio = AudioFile.new(recitation: rec, verse: verse, chapter_id: 1, verse_key: '1:4', verse_number: 4, url: 'spec.mp3').tap { |a| a.save!(validate: false) }
    audio.set_segments!([[1, 0, 400]])
    expect(audio.reload.ayah_id).to eq(verse.id)
    expect(audio.number_segments).to eq([[Word.find_by!(location: '1:4:1').number, 0, 400]])
    expect(rec.expected_ayahs_count).to eq(AyahNumbering.kufi.total_ayahs)
  end
end
