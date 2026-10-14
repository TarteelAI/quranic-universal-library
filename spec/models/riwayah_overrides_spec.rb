# frozen_string_literal: true

require 'rails_helper'

# P6.1: nullable riwayah_id on translations, tafsirs and word_translations.
# NULL is the shared row; a value marks an override for one riwayah, unique
# per (resource, verse|word, riwayah). The fixture slice has no rows in these
# tables, so the rows are written here without validations (languages are
# not in the slice).
RSpec.describe 'riwayah override columns (P6.1)' do
  let(:warsh) { Riwayah.find_by!(slug: 'warsh') }
  let(:qalun) { Riwayah.find_by!(slug: 'qalun') }
  let(:verse) { Verse.find_by!(verse_key: '1:4') }
  let(:word) { Word.find_by!(location: '1:4:1') }

  def translation(riwayah_id, text = 'x')
    Translation.new(resource_content_id: 131, verse_id: verse.id, language_id: 38, text: text, riwayah_id: riwayah_id).tap { |t| t.save!(validate: false) }
  end

  def word_translation(riwayah_id, text = 'x')
    WordTranslation.new(resource_content_id: 59, word_id: word.id, language_id: 38, text: text, riwayah_id: riwayah_id).tap { |t| t.save!(validate: false) }
  end

  it 'adds a nullable riwayah_id to the three tables, NULL on every existing row' do
    [Translation, Tafsir, WordTranslation].each do |model|
      expect(model.columns_hash['riwayah_id'].null).to be(true)
      expect(model.unscoped.where.not(riwayah_id: nil).count).to eq(0)
    end
  end

  it 'allows one override per riwayah beside the shared row, and leaves NULL rows unconstrained' do
    shared = translation(nil, 'Master of the Day of Judgement')
    override = translation(warsh.id, 'King of the Day of Judgement') # Warsh reads مَلِكِ
    expect(override.riwayah).to eq(warsh)
    expect(shared.riwayah).to be_nil
    expect { translation(qalun.id, 'King of the Day of Judgement') }.not_to raise_error
    expect { translation(warsh.id, 'a second Warsh override') }.to raise_error(ActiveRecord::RecordNotUnique)
    expect { translation(nil, 'a duplicate shared row, as the historical data has') }.not_to raise_error
  end

  it 'keys word glosses by word, resource and riwayah' do
    word_translation(nil, 'master')
    word_translation(warsh.id, 'king')
    expect { word_translation(warsh.id, 'again') }.to raise_error(ActiveRecord::RecordNotUnique)
    expect(WordTranslation.unscoped.where(word_id: word.id, resource_content_id: 59).count).to eq(2)
  end

  it 'has the composite index the translation readers need' do
    names = Verse.connection.indexes(:translations).map(&:name)
    expect(names).to include('index_translations_on_resource_content_id_and_verse_id', 'index_translations_riwayah_override')
    expect(Verse.connection.indexes(:tafsirs).map(&:name)).to include('index_tafsirs_riwayah_override')
    expect(Verse.connection.indexes(:word_translations).map(&:name)).to include('index_word_translations_riwayah_override')
  end
end
