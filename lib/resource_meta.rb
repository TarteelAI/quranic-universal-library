module ResourceMeta
  TITLES = {
    'mushaf-layout' => 'Mushaf Layouts',
    'recitations'   => 'Quran Recitations',
    'tafsir'        => 'Tafsir',
    'quran-script'  => 'Quran Script',
    'font'          => 'Quran Fonts',
    'quran-metadata'=> 'Quran Metadata',
    'similar-ayah'  => 'Similar Ayah',
    'ayah-theme'    => 'Ayah Themes',
    'mutashabihat'  => 'Mutashabihat Verses',
    'ayah-topics'   => 'Ayah Topics',
    'transliteration'=> 'Transliteration',
    'surah-info'    => 'Surah Information',
    'translation'   => 'Quran Translations'
  }.freeze

  DESCRIPTIONS = {
    'mushaf-layout'    => 'Download high-resolution Mushaf layouts optimized for printing and digital display, ensuring precise verse alignment and vibrant color fidelity.',
    'recitations'      => 'Listen to diverse Quranic recitations by renowned Qaris with adjustable audio clarity and variable playback speeds for personalized study.',
    'tafsir'           => 'Comprehensive Quranic exegesis detailing contextual insights and verse-by-verse explanations for deeper understanding.',
    'quran-script'     => 'Explore high-resolution Quranic Arabic scripts with authentic orthography and clear calligraphy for precise reading.',
    'font'             => 'Browse and download elegant, Quran-specific Arabic fonts optimized for readability and beautification across all devices.',
    'quran-metadata'   => 'Access detailed Quranic metadata including chapter and verse indices, classification, and structural information.',
    'similar-ayah'     => 'Discover verses with similar linguistic patterns and themes to enhance study and reflection on related passages.',
    'ayah-theme'       => 'Explore thematic categorization of Quranic verses for focused study on moral lessons and key topics.',
    'mutashabihat'     => 'Study the ambiguous (Mutashabihat) verses alongside scholarly interpretations for comprehensive comprehension.',
    'ayah-topics'      => 'Browse Quranic verses organized by topics to quickly find guidance on specific subjects and themes.',
    'transliteration'   => 'Read accurate transliterations of Quranic Arabic in Latin script to aid pronunciation and memorization of verses.',
    'surah-info'       => 'Find in-depth information on each chapter including revelation context, structure, and central themes.',
    'translation'      => 'Explore full Quran translations by various scholars with footnotes and context for every verse.'
  }.freeze

  module_function

  def title_for(key)
    TITLES[key.to_s] || key.to_s.humanize
  end

  def description_for(key)
    DESCRIPTIONS[key.to_s]
  end
end