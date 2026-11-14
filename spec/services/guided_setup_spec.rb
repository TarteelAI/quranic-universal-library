# frozen_string_literal: true

require 'clone_helper'

# The guided setup's mapping from answers to catalog filters and checklist items, and the
# answers it reads from a query string.
RSpec.describe GuidedSetup do
  let(:known_languages) { ['en', 'ur', 'id', 'ar'] }

  def answers(**input)
    GuidedSetup::Answers.from(input.transform_values { |value| Array(value).join(',') }, languages: known_languages)
  end

  def items(result)
    result.items.map { |item| [item.need.key, item.language].compact.join(':') }
  end

  describe '.result' do
    # One row per goal, then combinations of the other answers. Features left out follow the goals.
    [
      [{ goal: 'reader', platform: ['android', 'ios'], script: 'indopak', lang: ['ur', 'en'] },
       ['layout', 'font', 'text', 'translation:ur', 'translation:en', 'metadata'], ['sqlite'],],
      [{ goal: 'audio', platform: 'web', script: 'madani', lang: [] },
       ['text', 'recitation-timing', 'metadata'], ['json'],],
      [{ goal: 'study', platform: 'web', script: 'madani', lang: 'en' },
       ['font', 'text', 'translation:en', 'tafsir:en', 'surah-info:en'], ['json'],],
      [{ goal: 'learning', platform: 'cross', script: 'madani', lang: 'ur' },
       ['font', 'text', 'wbw:ur', 'translit:ur'], ['json', 'sqlite'],],
      [{ goal: 'research', platform: 'ml', script: 'madani', lang: [] },
       ['text', 'morphology', 'topics', 'themes', 'similar', 'mutashabihat'], ['json', 'csv'],],
      [{ goal: 'print', platform: 'print', script: ['madani', 'indopak'], lang: [] },
       ['layout', 'font', 'text', 'tajweed'], [],],
      # Two goals: the union of their features, in feature order.
      [{ goal: ['reader', 'audio'], platform: 'android', script: 'madani', lang: 'en' },
       ['layout', 'font', 'text', 'translation:en', 'recitation-timing', 'metadata'], ['sqlite'],],
      # Features chosen by hand replace the goal's; tajweed alone needs no plain text.
      [{ goal: 'reader', feature: 'tajweed', script: 'madani', lang: [] }, ['font', 'tajweed'], []],
      [{ goal: 'audio', feature: 'audio', script: 'madani', lang: [] }, ['recitation'], []],
      # No language: one item for each language need, over every language.
      [{ goal: 'study', feature: 'translation', script: 'madani', lang: [] }, ['translation'], []],
      # A phone and the web: both formats.
      [{ goal: 'reader', platform: ['android', 'web'], feature: 'nav', script: 'madani', lang: [] },
       ['metadata'], ['json', 'sqlite'],],
    ].each do |input, expected_items, expected_formats|
      it "maps #{input.to_json}" do
        result = described_class.result(answers(**input))

        expect(items(result)).to eq(expected_items)
        expect(result.formats).to eq(expected_formats)
      end
    end

    it 'puts the scripts on the script needs and the language on the language needs' do
      result = described_class.result(answers(goal: 'study', feature: ['mushaf', 'wbw'], script: ['madani', 'indopak'],
                                              lang: 'ur',))

      expect(result.items.to_h { |item| [item.need.key, item.filters] }).to eq(
        'layout' => { 'type' => 'mushaf-layout', 'script' => ['madani', 'indopak'] },
        'font' => { 'type' => 'font', 'script' => ['madani', 'indopak'] },
        'text' => { 'type' => 'quran-script', 'script' => ['madani', 'indopak'] },
        'wbw' => { 'type' => 'translation', 'granularity' => '1_word', 'language' => 'ur' },
      )
    end

    it 'gives each goal features that exist' do
      described_class::GOALS.each_value do |goal|
        expect(goal.features).to be_present.and(all(be_in(described_class::FEATURES.keys)))
      end
      described_class::FEATURES.each_value do |feature|
        expect(feature.needs).to be_present.and(all(be_in(described_class::NEEDS.keys)))
      end
    end
  end

  describe 'the catalog' do
    def search(filters)
      Catalog::SearchQuery.new(Catalog::SearchFilters.from(filters)).call
    end

    it 'accepts every filter value the mapping can produce' do
      languages = described_class.languages.map(&:key)
      [['madani'], ['indopak'], ['madani', 'indopak']].each do |scripts|
        input = { 'goal' => 'reader', 'feature' => described_class::FEATURES.keys.join(','),
                  'script' => scripts.join(','), 'lang' => languages.join(','), }
        described_class.result(GuidedSetup::Answers.from(input, languages:)).items.each do |item|
          applied = Catalog::SearchFilters.from(item.filters).to_h.slice(*item.filters.keys.map(&:to_sym))
          expect(applied.transform_keys(&:to_s)).to eq(item.filters)
        end
      end
    end

    # The test clones may lack the drafted script families: give a few scripts, fonts and
    # layouts one, and the tajweed scripts Madani.
    def assign_script_families
      published = DownloadableResource.published
      ['quran-script', 'font', 'mushaf-layout'].each do |type|
        published.where(resource_type: type).order(:id).first(2).zip(['madani', 'indopak'])
          .each { |resource, family| resource.update_columns(script_family: family) }
      end
      published.where(resource_type: 'quran-script').where('name ILIKE ?', '%tajweed%')
        .update_all(script_family: 'madani')
    end

    it 'finds at least one resource for every item of each goal' do
      assign_script_families
      languages = described_class.languages.map(&:key)
      described_class::GOALS.each_key do |goal|
        input = { 'goal' => goal, 'script' => 'madani,indopak', 'lang' => 'en' }
        result = described_class.result(GuidedSetup::Answers.from(input, languages:))
        totals = result.items.to_h { |item| [item.need.key, search(item.filters).total] }

        expect(totals.values).to all(be >= 1), "#{goal}: #{totals}"
      end
    end

    it 'lists the languages of the language types, most resources first' do
      languages = described_class.languages

      expect(languages.map(&:key)).to include('en', 'ur', 'ar', 'id')
      expect(languages.map(&:count)).to eq(languages.map(&:count).sort.reverse)
      english = Catalog::SearchQuery.new(Catalog::SearchFilters.from(language: 'en')).call.matches
      expect(languages.find { |language| language.key == 'en' }.count)
        .to eq(english.count { |row| described_class::LANGUAGE_TYPES.include?(row.resource.resource_type) })
    end
  end

  describe GuidedSetup::Answers do
    it 'drops unknown values, keeping the vocabulary order except for languages, which keep the order picked' do
      read = answers(goal: ['print', 'nope', 'reader'], platform: ['ios', 'mars'], feature: ['nav', 'x'],
                     script: ['other', 'indopak', 'madani'], lang: ['xx', 'ur', 'en'],)

      expect(read.to_h.slice(:goals, :platforms, :features, :scripts, :languages)).to eq(
        goals: ['reader', 'print'], platforms: ['ios'], features: ['nav'], scripts: ['madani', 'indopak'],
        languages: ['ur', 'en'],
      )
    end

    it 'opens at the first unanswered step, and at the last when all are answered' do
      expect(answers.step).to eq(0)
      expect(answers(goal: 'nope').step).to eq(0)
      expect(answers(goal: 'reader').step).to eq(1)
      expect(answers(goal: 'reader', platform: []).step).to eq(2)
      expect(answers(goal: 'reader', platform: 'mars').step).to eq(1)
      expect(answers(goal: 'reader', platform: 'ios', feature: 'nav').step).to eq(3)
      expect(answers(goal: 'reader', platform: 'ios', feature: 'nav', script: 'other').step).to eq(3)
      expect(answers(goal: 'reader', platform: 'ios', feature: 'nav', script: 'madani').step).to eq(4)
      expect(answers(goal: 'reader', platform: 'ios', feature: 'nav', script: 'madani', lang: []).step).to eq(4)
      expect(answers(goal: 'reader', script: 'madani', lang: 'en').step).to eq(1)
    end

    it 'reads arrays, comma lists and stray types without error' do
      read = described_class.from({ 'goal' => ['reader', { 'x' => 1 }], 'platform' => { '0' => 'ios' },
                                    'feature' => 42, 'lang' => 'en,ur', }, languages: known_languages,)

      expect(read.goals).to eq(['reader'])
      expect(read.platforms).to eq(['ios'])
      expect(read.features).to eq([])
      expect(read.languages).to eq(['en', 'ur'])
    end

    it 'writes the answers back as a query, features following the goals when not chosen' do
      expect(answers(goal: 'reader', platform: ['ios'], script: 'madani', lang: ['ur', 'en']).query).to eq(
        'goal' => 'reader', 'platform' => 'ios', 'feature' => 'mushaf,translation,nav', 'script' => 'madani',
        'lang' => 'ur,en',
      )
    end
  end
end
