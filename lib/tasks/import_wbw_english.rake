# frozen_string_literal: true

require 'open-uri'
require 'net/http'

namespace :wbw do
  WBW_DATA_CONFIG = {
    development: {
      type: :file,
      path: Rails.root.join('data', 'wbw-grammar-colored-translation'),
    },
    production: {
      type: :url,
      base_url: ENV.fetch('WBW_DATA_CDN_URL', 'CDN/qul/wbw-en-color-translation'),
    }
  }.freeze

  task detect_types: :environment do
    def fetch_chapter_data(chapter_number, config)
      case config[:type]
      when :file
        file_path = File.join(config[:path], "#{chapter_number}.json")
        return nil unless File.exist?(file_path)

        JSON.parse(File.read(file_path))
      when :url
        url = "#{config[:base_url]}/#{chapter_number}.json"
        begin
          uri = URI.parse(url)
          response = Net::HTTP.get_response(uri)
          response.code == '200' ? JSON.parse(response.body) : nil
        rescue StandardError => e
          puts "  Error fetching from #{url}: #{e.message}"
          nil
        end
      end
    end

    types = {}
    config = WBW_DATA_CONFIG[Rails.env.to_sym] || WBW_DATA_CONFIG[:development]

    1.upto(114) do |chapter_number|
      json_data = fetch_chapter_data(chapter_number, config)
      json_data['verses'].each do |verse_data|
        verse_data['words'].each do |word_data|
          word_data['englishParts'].each do |part|
            types[part['type']] ||= 0
            types[part['type']] += 1
          end

          (word_data['arabicParts'] || []).each do |part|
            types[part['type']] ||= 0
            types[part['type']] += 1
          end
        end
      end
    end
  end

  desc 'Import English word-by-word translations as Draft::WordTranslation'
  task import_english_wbw_colored_translation: :environment do
    language_id = 38

    resource = ResourceContent.translations.one_word.where(
      name: 'Colored English wbw translation',
      language_id: language_id
    ).first_or_create

    CSS_CLASS_MAPPING = {
      noun: 'n',
      preposition: 'p',
      paren: 'paren',
      'allah-name': 'pn',
      verb: 'v',
      bracket: 'punc',
      punctuation: 'punc'
    }.stringify_keys

    def fetch_chapter_data(chapter_number, config)
      case config[:type]
      when :file
        file_path = File.join(config[:path], "#{chapter_number}.json")
        return nil unless File.exist?(file_path)

        JSON.parse(File.read(file_path))
      when :url
        url = "#{config[:base_url]}/#{chapter_number}.json"
        begin
          uri = URI.parse(url)
          response = Net::HTTP.get_response(uri)
          response.code == '200' ? JSON.parse(response.body) : nil
        rescue StandardError => e
          puts "  Error fetching from #{url}: #{e.message}"
          nil
        end
      end
    end

    def build_html_from_english_parts(english_parts)
      return '' if english_parts.blank?

      english_parts.map do |part|
        next part['text'] if part['type'] == 'space'
        klass = CSS_CLASS_MAPPING[part['type'].to_s]
        "<span class='#{klass}'>#{part['text'].to_s.strip}</span>"
      end.join
    end

    config = WBW_DATA_CONFIG[Rails.env.to_sym] || WBW_DATA_CONFIG[:development]

    puts "Starting import for English (language_id: #{language_id})..."
    puts "Data source: #{config[:type]} (#{config[:type] == :file ? config[:path] : config[:base_url]})"
    puts "Environment: #{Rails.env}"
    puts "Total chapters: #{Chapter.count}"
    puts '-' * 60

    total_words_processed = 0
    total_words_created = 0
    total_words_updated = 0
    total_words_skipped = 0
    chapters_processed = 0
    chapters_failed = 0

    Chapter.order(:chapter_number).find_each do |chapter|
      chapter_number = chapter.chapter_number
      puts "\nProcessing Chapter #{chapter_number} - #{chapter.name_simple}..."

      begin
        json_data = fetch_chapter_data(chapter_number, config)

        unless json_data
          puts "  ✗ Skipping Chapter #{chapter_number} - data not available"
          chapters_failed += 1
          next
        end

        json_data['verses'].each do |verse_data|
          verse_number = verse_data['number']
          verse = Verse.find_by(chapter_id: chapter.id, verse_number: verse_number)

          unless verse
            puts "  Warning: Verse #{chapter_number}:#{verse_number} not found, skipping..."
            next
          end

          verse_words = verse.words.words.order(:position).to_a

          verse_data['words'].each_with_index do |word_data, index|
            total_words_processed += 1
            word = verse_words[index]

            unless word
              puts "  Warning: Word at position #{index + 1} not found for verse #{verse.verse_key}"
              total_words_skipped += 1
              next
            end

            english_html = build_html_from_english_parts(word_data['englishParts'])

            if english_html.blank?
              puts "  Warning: No english text found for word #{word.location}"
              total_words_skipped += 1
              next
            end

            draft_translation = Draft::WordTranslation.find_or_initialize_by(
              word_id: word.id,
              language_id: language_id,
              verse_id: verse.id,
              resource_content_id: resource.id
            )

            is_new = draft_translation.new_record?
            draft_translation.draft_text = english_html
            draft_translation.current_text = word.en_translation&.text
            draft_translation.imported = false
            draft_translation.need_review = true
            draft_translation.location = word.location

            if draft_translation.current_text.present?
              draft_translation.text_matched = (draft_translation.draft_text == draft_translation.current_text)
            end

            if draft_translation.save
              if is_new
                total_words_created += 1
              else
                total_words_updated += 1
              end
            else
              puts "  Error saving draft translation for word #{word.location}: #{draft_translation.errors.full_messages.join(', ')}"
              total_words_skipped += 1
            end
          end
        end

        chapters_processed += 1
        puts "  ✓ Completed Chapter #{chapter_number}"
      rescue StandardError => e
        chapters_failed += 1
        puts "  ✗ Error processing Chapter #{chapter_number}: #{e.message}"
        puts "    #{e.backtrace.first(3).join("\n    ")}"
      end
    end

    puts "\n" + ('=' * 60)
    puts 'Import Summary:'
    puts "  Chapters processed: #{chapters_processed}"
    puts "  Chapters failed: #{chapters_failed}"
    puts "  Total words processed: #{total_words_processed}"
    puts "  Words created: #{total_words_created}"
    puts "  Words updated: #{total_words_updated}"
    puts "  Words skipped: #{total_words_skipped}"
    puts ('=' * 60)
  end
end
