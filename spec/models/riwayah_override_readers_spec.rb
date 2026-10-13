# frozen_string_literal: true

require 'rails_helper'

# P6.2: for_riwayah returns one row per key — the riwayah's override where
# it has one, the shared row otherwise — as a chainable relation.
RSpec.describe RiwayahOverride do
  let(:warsh) { Riwayah.find_by!(slug: 'warsh') }
  let(:qalun) { Riwayah.find_by!(slug: 'qalun') }
  let(:v4) { Verse.find_by!(verse_key: '1:4') }
  let(:v5) { Verse.find_by!(verse_key: '1:5') }
  let(:w) { Word.find_by!(location: '1:4:1') }
  let(:w2) { Word.find_by!(location: '1:4:2') }

  def translation(verse, riwayah_id, text)
    Translation.new(resource_content_id: 131, verse_id: verse.id, language_id: 38, text: text, riwayah_id: riwayah_id).tap { |t| t.save!(validate: false) }
  end

  def gloss(word, riwayah_id, text)
    WordTranslation.new(resource_content_id: 59, word_id: word.id, language_id: 38, text: text, riwayah_id: riwayah_id).tap { |t| t.save!(validate: false) }
  end

  before do
    translation(v4, nil, 'Master of the Day of Judgement')
    translation(v4, warsh.id, 'King of the Day of Judgement')
    translation(v5, nil, 'You alone we worship')
    gloss(w, nil, 'master')
    gloss(w, warsh.id, 'king')
    gloss(w2, nil, '(of the) Day')
  end

  it 'reads the override for the riwayah and the shared row everywhere else' do
    rows = Translation.for_riwayah(warsh).where(resource_content_id: 131).order(:verse_id)
    expect(rows.map { |t| [t.verse_id, t.text, t.override?] }).to eq([[v4.id, 'King of the Day of Judgement', true], [v5.id, 'You alone we worship', false]])
    expect(Translation.for_riwayah(qalun).where(resource_content_id: 131).order(:verse_id).map(&:text)).to eq(['Master of the Day of Judgement', 'You alone we worship'])
    expect(Translation.for_riwayah(nil).where(resource_content_id: 131).count).to eq(2)
  end

  it 'leaves the plain scopes seeing every row' do
    expect(Translation.where(resource_content_id: 131).count).to eq(3)
    expect(Translation.shared.where(resource_content_id: 131).count).to eq(2)
    expect(Translation.overrides.where(resource_content_id: 131).pluck(:riwayah_id)).to eq([warsh.id])
  end

  it 'chains conditions and counts on the collapsed rows' do
    scope = Translation.for_riwayah(warsh).where(resource_content_id: 131, verse_id: v4.id)
    expect(scope.count).to eq(1)
    expect(scope.first.text).to eq('King of the Day of Judgement')
    expect(scope.to_sql).to include('DISTINCT ON')
  end

  it 'collapses word glosses by word and resource' do
    rows = WordTranslation.for_riwayah(warsh).where(resource_content_id: 59, word_id: [w.id, w2.id]).order(:word_id)
    expect(rows.map(&:text)).to eq(['king', '(of the) Day'])
    expect(WordTranslation.for_riwayah(Riwayah.hafs).where(resource_content_id: 59, word_id: [w.id, w2.id]).order(:word_id).map(&:text)).to eq(['master', '(of the) Day'])
  end
end
