# Elasticsearch configuration for advanced search system
require 'elasticsearch/model'

Elasticsearch::Model.client = Elasticsearch::Client.new(
  host: ENV.fetch('ELASTICSEARCH_URL', 'localhost:9200'),
  log: Rails.env.development?,
  transport_options: {
    request: { timeout: 30 }
  }
)

# Index names for different search types
module SearchConfig
  INDICES = {
    verses: "#{Rails.env}_quran_verses",
    translations: "#{Rails.env}_quran_translations", 
    morphology: "#{Rails.env}_quran_morphology",
    tafsirs: "#{Rails.env}_quran_tafsirs"
  }.freeze

  # Search types
  SEARCH_TYPES = %i[
    text
    morphology
    semantic
    root
    lemma
    stem
    pattern
    script_specific
  ].freeze

  # Supported Arabic scripts
  ARABIC_SCRIPTS = %i[
    qpc_hafs
    uthmani
    imlaei
    indopak
    qpc_nastaleeq
    uthmani_simple
  ].freeze

  # Morphological categories for POS search
  MORPHOLOGY_CATEGORIES = %i[
    noun
    verb
    particle
    pronoun
    proper_noun
    adjective
    adverb
  ].freeze
end