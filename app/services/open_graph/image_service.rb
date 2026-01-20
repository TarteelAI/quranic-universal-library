require 'digest'
require 'fileutils'

module OpenGraph
  class ImageService
    def initialize(locale:)
      @locale = locale.to_s
      @generator = OpenGraph::ImageGenerator.new(locale: @locale)
    end

    def ayah_path(verse)
      key = digest_key('ayah', @locale, verse.verse_key, verse.updated_at.to_i)
      path = build_path(key)
      return path if File.exist?(path)

      @generator.render_ayah(verse, path)
      path
    end

    def surah_path(chapter)
      key = digest_key('surah', @locale, chapter.chapter_number, chapter.updated_at.to_i)
      path = build_path(key)
      return path if File.exist?(path)

      @generator.render_surah(chapter, path)
      path
    end

    def word_path(word)
      key = digest_key('word', @locale, word.location.to_s, word.updated_at.to_i)
      path = build_path(key)
      return path if File.exist?(path)

      @generator.render_word(word, path)
      path
    end

    private

    def build_path(key)
      base = Rails.root.join('tmp', 'open_graph_images')
      FileUtils.mkdir_p(base)
      base.join("#{key}.png").to_s
    end

    def digest_key(*parts)
      Digest::SHA256.hexdigest(parts.map(&:to_s).join('|'))
    end
  end
end

