require 'elasticsearch/dsl'

module QuranSearchable
  extend ActiveSupport::Concern

  included do
    include Elasticsearch::Model
    include Elasticsearch::Model::Callbacks
    include Elasticsearch::DSL

    # Define analysis configuration
    ANALYSIS_CONFIG = {
      analysis: {
        filter: {
          quran_stemmer: {
            type: "stemmer",
            language: "arabic"
          },
          translit_ngram: {
            type: "edge_ngram",
            min_gram: 3,
            max_gram: 15
          },
          quran_synonyms: {
            type: "synonym",
            synonyms_path: "analysis/synonyms.txt",
            expand: false
          }
        },
        char_filter: {
          uthmani_filter: {
            type: "pattern_replace",
            pattern: "[^\u0621\u0623-\u063A\u0641-\u064A\u0640\u0651\u0653\u0654\u0670\u06D6-\u06ED]",
            replacement: ""
          },
          imlaei_filter: {
            type: "pattern_replace",
            pattern: "[^\u0621\u0623-\u063A\u0641-\u064A]",
            replacement: ""
          },
          indopak_nastaleeq_filter: {
            type: "pattern_replace",
            pattern: "[\uFD00-\uFD4F]",
            replacement: ""
          },
          qpc_nastaleeq_filter: {
            type: "pattern_replace",
            pattern: "[\uFD00-\uFDFF]",
            replacement: ""
          },
          digital_khatt_filter: {
            type: "pattern_replace",
            pattern: "[\u08A0-\u08FF\u0600-\u0605\u061C]",
            replacement: ""
          }
        },
        analyzer: {
          # Uthmani analyzers
          uthmani_analyzer: {
            type: "custom",
            tokenizer: "standard",
            char_filter: ["uthmani_filter"],
            filter: ["lowercase", "quran_stemmer", "quran_synonyms"]
          },

          # Imlaei analyzers
          imlaei_simple_analyzer: {
            type: "custom",
            tokenizer: "standard",
            char_filter: ["imlaei_filter"],
            filter: ["lowercase", "quran_synonyms"]
          },

          # IndoPak group analyzers
          indopak_nastaleeq_analyzer: {
            type: "custom",
            tokenizer: "standard",
            char_filter: ["indopak_nastaleeq_filter"],
            filter: ["lowercase", "quran_stemmer", "quran_synonyms"]
          },

          # Digital Khatt analyzers
          digital_khatt_analyzer: {
            type: "custom",
            tokenizer: "standard",
            char_filter: ["digital_khatt_filter"],
            filter: ["lowercase", "quran_synonyms"]
          },

          # Group analyzers
          group_indopak_analyzer: {
            type: "custom",
            tokenizer: "standard",
            filter: ["lowercase", "quran_stemmer", "quran_synonyms"]
          },

          # Transliteration analyzer
          translit_analyzer: {
            type: "custom",
            tokenizer: "whitespace",
            filter: ["lowercase", "asciifolding", "translit_ngram"]
          }
        }
      }
    }.freeze

    # Synonym mappings for simple texts
    SYNONYM_MAPPINGS = [
      "الظالمين, الظلمين => ظلم",
      "رحمن, رحمان => رحم",
      "الكتاب, الكتب => كتب"
    ].freeze

    settings ANALYSIS_CONFIG.deep_merge(
      index: { number_of_shards: 2, number_of_replicas: 1 }
    ) do
      mappings dynamic: false do
        # Common fields
        indexes :id, type: :keyword
        indexes :verse_key, type: :keyword

        # Text fields
        indexes :text_uthmani, type: :text, analyzer: :uthmani_analyzer
        indexes :text_indopak, type: :text, analyzer: :indopak_nastaleeq_analyzer
        indexes :text_imlaei_simple, type: :text, analyzer: :imlaei_simple_analyzer
        indexes :text_imlaei, type: :text, analyzer: :uthmani_analyzer
        indexes :text_uthmani_simple, type: :text, analyzer: :imlaei_simple_analyzer
        indexes :text_qpc_hafs, type: :text, analyzer: :uthmani_analyzer

        # Grouped fields
        indexes :text_indopak_nastaleeq, type: :text,
                analyzer: :indopak_nastaleeq_analyzer,
                copy_to: "group_indopak"

        indexes :text_qpc_nastaleeq, type: :text,
                analyzer: :indopak_nastaleeq_analyzer,
                copy_to: "group_indopak"

        indexes :text_digital_khatt_indopak, type: :text,
                analyzer: :digital_khatt_analyzer,
                copy_to: "group_indopak"

        indexes :group_indopak, type: :text, analyzer: :group_indopak_analyzer

        # Transliteration
        indexes :transliteration, type: :text, analyzer: :translit_analyzer do
          indexes :exact, type: :keyword
        end

        # Words nested field
        indexes :words, type: :nested do
          indexes :id, type: :keyword
          indexes :text, type: :text, analyzer: :uthmani_analyzer
          indexes :transliteration, type: :text, analyzer: :translit_analyzer
        end
      end
    end

    # Custom index name
    index_name "quran_verses_#{Rails.env}"

    # Define how documents should be indexed (with character removal)
    def as_indexed_json(options={})
      {
        id: id,
        verse_key: verse_key,
        text_uthmani: clean_text(text_uthmani, :text_uthmani),
        text_indopak: clean_text(text_indopak, :text_indopak),
        text_imlaei_simple: clean_text(text_imlaei_simple, :text_imlaei_simple),
        text_imlaei: clean_text(text_imlaei, :text_uthmani), # Same as Uthmani
        text_uthmani_simple: clean_text(text_uthmani_simple, :text_imlaei_simple),
        text_qpc_hafs: clean_text(text_qpc_hafs, :text_uthmani), # Same as Uthmani
        text_indopak_nastaleeq: clean_text(text_indopak_nastaleeq, :text_indopak_nastaleeq),
        text_qpc_nastaleeq: clean_text(text_qpc_nastaleeq, :text_qpc_nastaleeq),
        text_digital_khatt: clean_text(text_digital_khatt, :text_digital_khatt),
        text_digital_khatt_indopak: clean_text(text_digital_khatt_indopak, :text_digital_khatt),
        transliteration: Translation.where(resource_content_id: 57, verse_id: id).first&.text,
        words: words_for_indexing,
      }
    end

    private

    # Clean text based on script-specific rules
    def clean_text(text, field_name)
      #pattern = REMOVAL_PATTERNS[field_name]
      #return text if pattern.blank?

      #text.gsub(pattern, '')
      text
    end

    # Index words with cleaned text
    def words_for_indexing
      words.map do |word|
        {
          id: word.id,
          text_uthmani: clean_text(word.text_uthmani, :text_uthmani),
          transliteration: word.en_transliteration,
          position: word.position,
        }
      end
    end

    protected

    REMOVAL_CHARS = {
      text_indopak_nastaleeq: (0xFD00..0xFD4F).to_a,
      text_qpc_nastaleeq: (0xFD00..0xFDFF).to_a,
      text_indopak: [0xE003, 0xE004, 0xE01A, 0xE01B, 0xE01E, 0xE01F, 0xE022]
    }.freeze


    REMOVAL_PATTERNS = {
      text_uthmani: /[^\u0621\u0623-\u063A\u0641-\u064A\u0640\u0651\u0653\u0654\u0670\u06D6-\u06ED]/,
      text_indopak: /[\uFD3E\uFD3F\u08A0-\u08FF\u0600-\u0605\u061C]/,
      text_imlaei_simple: /[^\u0621\u0623-\u063A\u0641-\u064A]/,
      text_qpc_nastaleeq: /[\uFD00-\uFDFF]/,
      text_digital_khatt: /[\u08A0-\u08FF\u0600-\u0605\u061C]/,
      text_indopak_nastaleeq: /[\uFD00-\uFD4F]/
    }.freeze

    def prepare_unicode_range(codepoints)
      ranges = codepoints.slice_when { |i,j| j > i + 1 }.map do |seq|
        if seq.size == 1
          "\\u#{seq.first.to_s(16).rjust(4, '0')}"
        else
          "\\u#{seq.first.to_s(16).rjust(4, '0')}-\\u#{seq.last.to_s(16).rjust(4, '0')}"
        end
      end
      "[#{ranges.join}]"
    end
  end

  module ClassMethods
    def custom_analysis
      ANALYSIS_CONFIG
    end

    def synonym_mappings
      SYNONYM_MAPPINGS
    end

    def analyze_text(text, analyzer: :uthmani_analyzer)
      __elasticsearch__.client.indices.analyze(
        index: index_name,
        body: {
          analyzer: analyzer,
          text: text
        }
      )
    end

    def es_mappings
      __elasticsearch__.mappings
    end

    def es_settings
      __elasticsearch__.settings
    end
  end
end