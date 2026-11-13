# frozen_string_literal: true

# The guided setup (/start): its five questions and the mapping from the answers to what the app
# needs from the catalog. Each need is a checklist item with the catalog filters that list its
# resources (Catalog::SearchFilters values). It knows nothing of controllers, requests or the
# session, so kits and the public API can reuse it.
module GuidedSetup
  Goal = Data.define(:key, :label, :blurb, :features)
  Platform = Data.define(:key, :label, :hint, :formats)
  Feature = Data.define(:key, :label, :needs)
  # `filters` are the catalog filters of the need; `scripts` and `languages` say whether the
  # answers' scripts and languages narrow it.
  Need = Data.define(:key, :label, :filters, :scripts, :languages)
  Script = Data.define(:key, :label, :blurb)
  Language = Data.define(:key, :name, :count)

  # One checklist item: a need, for one language when the need has languages and some were picked.
  Item = Data.define(:need, :language, :filters)
  # `formats` are the file formats that suit the platforms, in catalog format order.
  Result = Data.define(:items, :formats)

  # The steps, named by their query key.
  STEPS = ['goal', 'platform', 'feature', 'script', 'lang'].freeze
  # Steps that need at least one pick; the others can be answered with none.
  REQUIRED_STEPS = ['goal', 'script'].freeze

  GOALS = [
    Goal.new(key: 'reader', label: 'Quran reader app',
             blurb: 'Show the Quran page by page or ayah by ayah, like a printed mushaf.',
             features: ['mushaf', 'translation', 'nav'],),
    Goal.new(key: 'audio', label: 'Audio and recitation',
             blurb: 'Play reciters and highlight each word as it is recited.',
             features: ['audio', 'highlight', 'nav'],),
    Goal.new(key: 'study', label: 'Translation and tafsir',
             blurb: 'Help people understand the meaning in their language.',
             features: ['ayah', 'translation', 'tafsir', 'surah-info'],),
    Goal.new(key: 'learning', label: 'Learning and word by word',
             blurb: 'Teach Arabic with word meanings, transliteration and grammar.',
             features: ['ayah', 'wbw', 'translit'],),
    Goal.new(key: 'research', label: 'Research, NLP and AI',
             blurb: 'Analyse the text, train models or ground an agent.',
             features: ['search', 'topics', 'similar'],),
    Goal.new(key: 'print', label: 'Print, images and video',
             blurb: 'Render pages, ayah cards and subtitles at high quality.',
             features: ['mushaf', 'tajweed'],),
  ].index_by(&:key).freeze

  PLATFORMS = [
    Platform.new(key: 'web', label: 'Web', hint: 'JSON files', formats: ['json']),
    Platform.new(key: 'ios', label: 'iOS', hint: 'SQLite files', formats: ['sqlite']),
    Platform.new(key: 'android', label: 'Android', hint: 'SQLite files', formats: ['sqlite']),
    Platform.new(key: 'cross', label: 'Flutter or React Native', hint: 'SQLite or JSON files',
                 formats: ['sqlite', 'json'],),
    Platform.new(key: 'print', label: 'Print and video', hint: 'Fonts, layouts and images', formats: []),
    Platform.new(key: 'ml', label: 'Data or ML pipeline', hint: 'CSV or JSON files', formats: ['csv', 'json']),
  ].index_by(&:key).freeze

  FEATURES = [
    Feature.new(key: 'mushaf', label: 'Mushaf pages', needs: ['layout', 'font', 'text']),
    Feature.new(key: 'ayah', label: 'Ayah by ayah reading', needs: ['text', 'font']),
    Feature.new(key: 'audio', label: 'Audio playback', needs: ['recitation']),
    Feature.new(key: 'highlight', label: 'Highlighting while reciting', needs: ['recitation-timing', 'text']),
    Feature.new(key: 'translation', label: 'Translation', needs: ['translation']),
    Feature.new(key: 'tafsir', label: 'Tafsir', needs: ['tafsir']),
    Feature.new(key: 'surah-info', label: 'Surah introductions', needs: ['surah-info']),
    Feature.new(key: 'wbw', label: 'Word by word meaning', needs: ['wbw']),
    Feature.new(key: 'translit', label: 'Transliteration', needs: ['translit']),
    Feature.new(key: 'tajweed', label: 'Tajweed colours', needs: ['tajweed', 'font']),
    Feature.new(key: 'search', label: 'Search and morphology', needs: ['morphology', 'text']),
    Feature.new(key: 'topics', label: 'Topics and themes', needs: ['topics', 'themes']),
    Feature.new(key: 'similar', label: 'Similar ayahs and phrases', needs: ['similar', 'mutashabihat']),
    Feature.new(key: 'nav', label: 'Juz and hizb navigation', needs: ['metadata']),
  ].index_by(&:key).freeze

  # In checklist order. Tajweed scripts and recitations with timing are found by the words of
  # their names and tags, as the catalog search finds them.
  NEEDS = [
    Need.new(key: 'layout', label: 'Mushaf layout', filters: { 'type' => 'mushaf-layout' }, scripts: true,
             languages: false,),
    Need.new(key: 'font', label: 'Quran font', filters: { 'type' => 'font' }, scripts: true, languages: false),
    Need.new(key: 'text', label: 'Quran text', filters: { 'type' => 'quran-script' }, scripts: true,
             languages: false,),
    Need.new(key: 'tajweed', label: 'Tajweed text', filters: { 'type' => 'quran-script', 'q' => 'tajweed' },
             scripts: true, languages: false,),
    Need.new(key: 'translation', label: 'Translation',
             filters: { 'type' => 'translation', 'granularity' => '1_ayah' }, scripts: false, languages: true,),
    Need.new(key: 'wbw', label: 'Word by word translation',
             filters: { 'type' => 'translation', 'granularity' => '1_word' }, scripts: false, languages: true,),
    Need.new(key: 'translit', label: 'Transliteration', filters: { 'type' => 'transliteration' }, scripts: false,
             languages: true,),
    Need.new(key: 'tafsir', label: 'Tafsir', filters: { 'type' => 'tafsir' }, scripts: false, languages: true),
    Need.new(key: 'surah-info', label: 'Surah introductions', filters: { 'type' => 'surah-info' }, scripts: false,
             languages: true,),
    Need.new(key: 'recitation', label: 'Recitation', filters: { 'type' => 'recitation' }, scripts: false,
             languages: false,),
    Need.new(key: 'recitation-timing', label: 'Recitation with timing',
             filters: { 'type' => 'recitation', 'q' => 'segments' }, scripts: false, languages: false,),
    Need.new(key: 'morphology', label: 'Morphology', filters: { 'type' => 'morphology' }, scripts: false,
             languages: false,),
    Need.new(key: 'topics', label: 'Ayah topics', filters: { 'type' => 'ayah-topics' }, scripts: false,
             languages: false,),
    Need.new(key: 'themes', label: 'Ayah themes', filters: { 'type' => 'ayah-theme' }, scripts: false,
             languages: false,),
    Need.new(key: 'similar', label: 'Similar ayahs', filters: { 'type' => 'similar-ayah' }, scripts: false,
             languages: false,),
    Need.new(key: 'mutashabihat', label: 'Mutashabihat', filters: { 'type' => 'mutashabihat' }, scripts: false,
             languages: false,),
    Need.new(key: 'metadata', label: 'Juz, hizb and page data', filters: { 'type' => 'quran-metadata' },
             scripts: false, languages: false,),
  ].index_by(&:key).freeze

  SCRIPTS = [
    Script.new(key: 'madani', label: 'Madani (Uthmani)',
               blurb: 'Read across the Arab world, Turkey, Indonesia and most of the world.',),
    Script.new(key: 'indopak', label: 'IndoPak',
               blurb: 'Familiar to readers in Pakistan, India, Bangladesh and South Africa.',),
  ].index_by(&:key).freeze

  # The choices of each step but the languages, which come from the catalog.
  CHOICES = { 'goal' => GOALS.keys, 'platform' => PLATFORMS.keys, 'feature' => FEATURES.keys,
              'script' => SCRIPTS.keys, }.freeze

  # The resource types the language step is about.
  LANGUAGE_TYPES = NEEDS.values.select(&:languages).map { |need| need.filters.fetch('type') }.uniq.freeze

  # The answers of a setup, read from a query string (`goal=reader,audio&platform=ios&…`): each
  # key holds a comma list, an array or an indexed hash. Values outside the vocabularies are
  # dropped, never an error. `answered` are the steps the query answers: a step that needs a pick
  # is answered by a known value, the others also by an empty value.
  class Answers < Data.define(:goals, :platforms, :features, :scripts, :languages, :answered)
    # `languages` are the language keys the language step offers.
    def self.from(input, languages:)
      input = input.to_h.transform_keys(&:to_s)
      known = STEPS.index_with { |key| known(key, list(input[key]), languages) }
      answered = STEPS.select { |key| known[key].any? || (input[key] == '' && REQUIRED_STEPS.exclude?(key)) }
      new(goals: known['goal'], platforms: known['platform'], features: known['feature'],
          scripts: known['script'], languages: known['lang'], answered: answered,)
    end

    # Languages keep the order they were picked in; the other answers take the vocabulary's order.
    def self.known(key, values, languages)
      key == 'lang' ? values & languages : CHOICES.fetch(key) & values
    end

    def self.list(value)
      values = case value
               when Array then value
               when Hash then value.values
               when String then value.split(',')
               else []
               end
      values.grep(String).map(&:strip).uniq
    end
    private_class_method :known, :list

    # The index of the step to open: the first unanswered one, else the last.
    def step
      STEPS.index { |key| answered.exclude?(key) } || (STEPS.size - 1)
    end

    # The features chosen, or the goals' features while the features step is unanswered.
    def needed_features
      return features if answered.include?('feature')

      chosen = goals.flat_map { |goal| GOALS.fetch(goal).features }
      FEATURES.keys & chosen
    end

    # Every answer as a query (comma lists), the features filled in from the goals.
    def query
      { 'goal' => goals, 'platform' => platforms, 'feature' => needed_features, 'script' => scripts,
        'lang' => languages, }.transform_values { |values| values.join(',') }
    end
  end

  def self.result(answers)
    Result.new(items: needs(answers).flat_map { |need| items(need, answers) }, formats: formats(answers.platforms))
  end

  # The languages of the language types in the published catalog, most resources first.
  def self.languages
    rows = Catalog::SearchQuery.new(Catalog::SearchFilters.from({})).call.matches
    counts = rows.select { |row| LANGUAGE_TYPES.include?(row.resource.resource_type) }.filter_map(&:language).tally
    counts.map { |language, count| Language.new(key: language.iso_code, name: language.name, count: count) }
      .sort_by { |language| [-language.count, language.name] }
  end

  def self.needs(answers)
    features = answers.needed_features
    keys = features.flat_map { |feature| FEATURES.fetch(feature).needs }
    # A narrower need covers the broad one, and tajweed text alone covers the plain text.
    keys.delete('recitation') if keys.include?('recitation-timing')
    keys.delete('text') if keys.include?('tajweed') && !features.intersect?(['mushaf', 'ayah', 'search'])
    NEEDS.values.select { |need| keys.include?(need.key) }
  end

  def self.items(need, answers)
    filters = need.filters
    filters = filters.merge('script' => answers.scripts) if need.scripts && answers.scripts.any?
    return [Item.new(need: need, language: nil, filters: filters)] unless need.languages && answers.languages.any?

    answers.languages.map do |language|
      Item.new(need: need, language: language, filters: filters.merge('language' => language))
    end
  end

  def self.formats(platforms)
    wanted = platforms.flat_map { |platform| PLATFORMS.fetch(platform).formats }
    Catalog::Taxonomy.formats.map(&:key) & wanted
  end

  private_class_method :needs, :items, :formats
end
