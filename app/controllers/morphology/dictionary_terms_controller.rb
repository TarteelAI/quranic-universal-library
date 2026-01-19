module Morphology
  class DictionaryTermsController < ApplicationController
    def show
      @locale = params[:locale].presence || I18n.locale.to_s
      @category = params[:category].to_s
      @key = params[:key].to_s

      title, html = load_term_content(@category, @key, @locale)
      @title = title.presence || @key
      @html = render_embeds(html)
    end

    private

    def render_embeds(html)
      s = html.to_s

      s = s.gsub(/\{graph\s+ayah=(?<ayah>\d+:\d+)\s*\}/) do
        render_to_string(
          partial: 'morphology/dictionary_terms/embeds/graph',
          locals: { ayah_key: Regexp.last_match[:ayah] }
        )
      end

      s.gsub(/\{word\s+location=(?<loc>\d+:\d+:\d+)\s*\}/) do
        render_to_string(
          partial: 'morphology/dictionary_terms/embeds/word',
          locals: { location: Regexp.last_match[:loc] }
        )
      end
    end

    def load_term_content(category, key, locale)
      normalized_category = normalize_category(category)
      term = Morphology::DictionaryTerm.find_by(category: normalized_category, key: key)
      translation = term&.translation_for(locale)

      if translation&.definition.present?
        return [translation.title, translation.definition]
      end

      load_from_file(normalized_category, key, locale)
    end

    def normalize_category(category)
      c = category.to_s.strip
      return 'pos_tags' if c == 'pos_tag'
      return 'edge_relations' if c == 'edge_relation'
      c
    end

    def load_from_file(category, key, locale)
      base = Rails.root.join('data', 'morphology_dictionary')
      file = base.join(locale.to_s, category.to_s, "#{key}.html")
      file = base.join('en', category.to_s, "#{key}.html") unless File.exist?(file)
      raise ActiveRecord::RecordNotFound unless File.exist?(file)

      html = File.read(file)
      body = html[/<body>(.*)<\/body>/m, 1].to_s
      title = body[/<h1>(.*?)<\/h1>/m, 1].to_s
      body = body.sub(/<h1>.*?<\/h1>/m, '').strip

      [title, body]
    end
  end
end

