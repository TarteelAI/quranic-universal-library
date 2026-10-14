# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('lib/qiraat/gloss_override').to_s

# P6.4: the word-by-word tool with a riwayah selected. Warsh forms of
# al-Fatihah come from the fixture word index (upserted into word_texts),
# the numbering from the slice's counting data, the differing word 1:4:1
# from the differences import. Without a riwayah nothing changes (render
# parity covers the Hafs HTML).
RSpec.describe 'Word-by-word tool with a riwayah (P6.4)', type: :request do
  let(:warsh) { Riwayah.find_by!(slug: 'warsh') }
  let(:warsh_script) { Script.find_by!(slug: 'qpc-warsh') }
  let(:v4) { Verse.find_by!(verse_key: '1:4') }
  let(:malik) { Word.find_by!(location: '1:4:1') }
  let(:rc) { ResourceContent.create!(name: 'spec wbw', sub_type: ResourceContent::SubType::Translation, cardinality_type: ResourceContent::CardinalityType::OneWord, resource_type: 'Word', language_id: 38, language_name: 'english', approved: true) }

  before do
    sign_in_admin
    Language.create!(id: 38, name: 'English', iso_code: 'en') unless Language.exists?(38)
    AyahMapping.delete_all
    NumberedAyah.delete_all
    AyahNumbering.delete_all
    WordDifference.delete_all
    Qiraat::Backfill::WordNumbers.new(csv_path: QiraatFixtures.upstream('word-index.csv'), dry_run: false, logger: nil).call
    Qiraat::Import::Numberings.new(counting_path: QiraatFixtures.upstream('counting.json'), catalog_path: QiraatFixtures.upstream('catalog.json'), systems: %w[kufi madani-last], surahs: [1, 2]).call
    Qiraat::Import::AyahMappings.new.call
    warsh.update!(default_numbering: AyahNumbering.find_by!(slug: 'madani-last'))
    Qiraat::Import::WordDifferences.new(path: QiraatFixtures.upstream('differences.json'), word_index_path: QiraatFixtures.upstream('word-index.csv')).call
    forms = QiraatFixtures.word_index.select { |r| r['surah'] == '1' }.to_h { |r| [r['number'].to_i, r['form_warsh']] }
    rows = Word.unscoped.where(verse_id: Verse.where(chapter_id: 1).select(:id)).where.not(number: nil).map { |w| { script_id: warsh_script.id, word_id: w.id, text: forms[w.number] } }.select { |r| r[:text].present? }
    WordText.upsert_all(rows, unique_by: %i[script_id word_id])
    # a reference translation beside the words, and a shared gloss for 1:4:1
    tr = ResourceContent.create!(name: 'spec translation', sub_type: ResourceContent::SubType::Translation, cardinality_type: ResourceContent::CardinalityType::OneVerse, resource_type: 'Verse', language_id: 38, priority: 1, meta_data: { 'wbw-reference' => 'yes' })
    Translation.new(resource_content_id: tr.id, verse_id: v4.id, language_id: 38, text: 'Master of the Day of Judgment', resource_name: 'spec translation').save!(validate: false)
    Translation.new(resource_content_id: tr.id, verse_id: v4.id, language_id: 38, text: 'King of the Day of Judgment', resource_name: 'spec translation', riwayah_id: warsh.id).save!(validate: false)
    WordTranslation.new(resource_content_id: rc.id, word_id: malik.id, language_id: 38, language_name: 'english', text: 'Master').save!(validate: false)
  end

  it 'renders Warsh 1:3 (Kufi 1:4) in the Warsh face, with its ayah number, badge, override field and translation override' do
    get "/word_translations/new?resource_id=#{rc.id}&ayah=1:4&riwayah=warsh"
    expect(response).to have_http_status(:ok)
    body = response.body
    expect(body).to include('ayah 3 (Kufi 4)')
    expect(body).to include('id="riwayah-notice"')
    expect(body).to include("class=\"#{warsh_script.font_css_class} text-2xl leading-none\" dir=\"rtl\">#{malik.text_for(warsh_script)}<")
    expect(body).to include("value=\"#{warsh.id}\"").and include('[riwayah_id]')
    expect(body).to include('Shared gloss:').and include('Master')
    expect(body).to include('dotting variant') # the badge for 1:4:1
    expect(body).to include('King of the Day of Judgment') # the Warsh translation override
    expect(body).not_to include('Master of the Day of Judgment')
  end

  it 'keeps the Hafs page free of riwayah fields' do
    get "/word_translations/new?resource_id=#{rc.id}&ayah=1:4"
    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include('[riwayah_id]')
    expect(response.body).not_to include('riwayah-notice')
    expect(response.body).to match(/ayah 4\b/).and(satisfy { |b| !b.include?('Kufi 4') })
    expect(response.body).to include('Master of the Day of Judgment')
  end

  it 'saves an override row for the riwayah and leaves the shared gloss alone' do
    post '/word_translations', params: { verse_id: v4.id, resource_id: rc.id, riwayah: 'warsh',
                                         verse: { word_translations_attributes: { '0' => { word_id: malik.id, language_id: 38, resource_content_id: rc.id, riwayah_id: warsh.id, text: 'King' } } } }
    expect(response).to redirect_to(%r{/word_translations/#{v4.id}\?.*riwayah=warsh})
    expect(WordTranslation.shared.find_by(word_id: malik.id, resource_content_id: rc.id).text).to eq('Master')
    expect(WordTranslation.overrides_for(warsh).find_by(word_id: malik.id, resource_content_id: rc.id).text).to eq('King')
    expect(WordTranslation.for_riwayah(warsh).find_by(word_id: malik.id, resource_content_id: rc.id).text).to eq('King')

    get "/word_translations/#{v4.id}?resource_id=#{rc.id}&riwayah=warsh"
    expect(response.body).to include('King').and include('Warsh override')
    get "/word_translations/#{v4.id}?resource_id=#{rc.id}"
    expect(response.body).to include('Master').and(satisfy { |b| !b.include?('Warsh override') })
  end

  it 'offers the riwayat with row-backed scripts in the index filter' do
    get "/word_translations?resource_id=#{rc.id}&filter_chapter=1"
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('<option value="warsh">Warsh</option>').and include('<option selected="selected" value="hafs">Hafs (default)</option>')
    get "/word_translations?resource_id=#{rc.id}&filter_chapter=1&riwayah=warsh"
    expect(response.body).to include("riwayah=warsh").and include(warsh_script.font_css_class)
  end
end
