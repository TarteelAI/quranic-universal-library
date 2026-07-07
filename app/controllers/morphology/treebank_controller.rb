module Morphology
  class TreebankController < CommunityController
    def index
      scope = Verse.all

      if params[:filter_chapter].present?
        scope = scope.where(chapter_id: params[:filter_chapter].to_i)
      end

      if params[:verse_number].present?
        scope = scope.where(verse_number: params[:verse_number].to_i)
      end

      if params[:verse_key].present?
        parts = params[:verse_key].to_s.strip.split(':')
        if parts.length >= 2
          scope = scope.where(chapter_id: parts[0].to_i, verse_number: parts[1].to_i)
        end
      end

      if params[:root_id].present?
        scope = scope.where(
          <<~SQL.squish,
            EXISTS (
              SELECT 1
              FROM morphology_word_tokens wt
              WHERE wt.chapter_number = verses.chapter_id
                AND wt.verse_number = verses.verse_number
                AND wt.root_id = ?
            )
          SQL
          params[:root_id].to_i
        )
      end

      if params[:lemma_id].present?
        scope = scope.where(
          <<~SQL.squish,
            EXISTS (
              SELECT 1
              FROM morphology_word_tokens wt
              WHERE wt.chapter_number = verses.chapter_id
                AND wt.verse_number = verses.verse_number
                AND wt.lemma_id = ?
            )
          SQL
          params[:lemma_id].to_i
        )
      end

      if params[:pos_tag].present?
        scope = scope.where(
          <<~SQL.squish,
            EXISTS (
              SELECT 1
              FROM morphology_word_tokens wt
              WHERE wt.chapter_number = verses.chapter_id
                AND wt.verse_number = verses.verse_number
                AND wt.pos_key = ?
            )
          SQL
          params[:pos_tag].to_s
        )
      end

      if params[:rel_label].present?
        scope = scope.where(
          <<~SQL.squish,
            EXISTS (
              SELECT 1
              FROM morphology_word_tokens wt
              WHERE wt.chapter_number = verses.chapter_id
                AND wt.verse_number = verses.verse_number
                AND wt.rel_label = ?
            )
          SQL
          params[:rel_label].to_s
        )
      end

      scope = scope.order('verse_index ASC')
      @pagy, @verses = pagy(scope, items: 100, page: params[:page] || 1)

      pairs = @verses.map { |v| [v.chapter_id, v.verse_number] }
      if pairs.any?
        pair_placeholders = pairs.map { '(?,?)' }.join(',')
        counts_by_verse = Morphology::WordToken
          .where(Arel.sql("(chapter_number, verse_number) IN (#{pair_placeholders})"), *pairs.flatten)
          .group(:chapter_number, :verse_number)
          .pluck(
            :chapter_number,
            :verse_number,
            Arel.sql('COUNT(DISTINCT sentence_id)'),
            Arel.sql('COUNT(*)')
          )
          .each_with_object({}) do |(ch, vn, sc, tc), h|
            h[[ch, vn]] = { sentences_count: sc, tokens_count: tc }
          end
      else
        counts_by_verse = {}
      end

      @verses.each do |verse|
        counts = counts_by_verse[[verse.chapter_id, verse.verse_number]] || {}
        verse.define_singleton_method(:sentences_count) { counts[:sentences_count].to_i }
        verse.define_singleton_method(:tokens_count) { counts[:tokens_count].to_i }
      end

      cache_key = "treebank_options/#{Morphology::WordToken.maximum(:updated_at).to_i}"

      @rel_label_options, @root_options, @lemma_options = Rails.cache.fetch(cache_key) do
        rel_labels = Morphology::WordToken.where.not(rel_label: nil).distinct.order(:rel_label).pluck(:rel_label).map do |label|
          [I18n.t("morphology.edge_relations.#{label}", default: label), label]
        end

        roots = Root.where(
          id: Morphology::WordToken.where.not(root_id: nil).select(:root_id)
        ).order(:text_clean).pluck(:text_clean, :id)

        lemmas = Lemma.where(
          id: Morphology::WordToken.where.not(lemma_id: nil).select(:lemma_id)
        ).order(:text_clean).pluck(:text_madani, :id)

        [rel_labels, roots, lemmas]
      end

      @pos_tag_options = Corpus::Morphology::PartOfSpeech.all.map do |pos|
        label = I18n.t("morphology.pos_tags.#{pos.tag}", default: pos.tag)
        ["#{label} (#{pos.tag})", pos.tag]
      end.sort_by { |opt| opt[0] }
    end

    def show
      @chapter_number = params[:chapter].to_i
      @verse_number   = params[:verse].to_i
      @locale = %w[en ar].include?(params[:locale].to_s) ? params[:locale].to_s : 'ar'

      @verse = Verse.find_by(chapter_id: @chapter_number, verse_number: @verse_number)
      return head :not_found unless @verse

      @sentences = Morphology::Sentence
        .where(chapter_id: @chapter_number)
        .where('first_verse_id <= ? AND last_verse_id >= ?', @verse.id, @verse.id)
        .order(:sentence_number)
        .includes(:word_tokens)

      @irab_tokens = @sentences.flat_map(&:word_tokens)

      @irab_translator = ->(key, locale:, default:) { I18n.t(key, locale: locale, default: default) }

      @prev_verse = @verse.previous_ayah
      @next_verse = @verse.next_ayah

      @data_url = morphology_treebank_ayah_data_path(@chapter_number, @verse_number, locale: @locale)
    end

    def data
      chapter_number = params[:chapter].to_i
      verse_number   = params[:verse].to_i
      locale = %w[en ar].include?(params[:locale].to_s) ? params[:locale].to_s : 'ar'

      verse = Verse.find_by(chapter_id: chapter_number, verse_number: verse_number)
      return head :not_found unless verse

      chapter = Chapter.find_by(chapter_number: chapter_number)

      cache_key = ['treebank-data', chapter_number, verse_number, locale, Morphology::WordToken.maximum(:updated_at)]

      payload = Rails.cache.fetch(cache_key) do
        sentences = Morphology::Sentence
          .where(chapter_id: chapter_number)
          .where('first_verse_id <= ? AND last_verse_id >= ?', verse.id, verse.id)
          .order(:sentence_number)
          .includes(:word_tokens)

        presenter = Morphology::TreebankPresenter.new(
          verse: verse,
          sentences: sentences,
          locale: locale,
          chapter: chapter
        )
        presenter.to_json_payload
      end

      render json: payload
    end
  end
end
