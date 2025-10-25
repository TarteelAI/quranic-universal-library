class QuranExplorerController < ApplicationController
  before_action :load_chapter, only: [:surah, :ayah]
  before_action :load_verse, only: [:ayah, :word]
  before_action :load_word, only: [:word]

  def index
    @chapters = Chapter.includes(:translated_names).order(:chapter_number)
  end

  def surah
    @chapter_info = ChapterInfo.where(chapter_id: @chapter.id, language_id: 38).first # English
    @verses = @chapter.verses.includes(:translations, :audio_files).limit(10)
    @stats = {
      verses_count: @chapter.verses_count,
      words_count: @chapter.verses.sum(:words_count) || 0,
      pages: @chapter.pages,
      rukus_count: @chapter.rukus_count
    }
  rescue => e
    Rails.logger.error "Error loading surah #{@chapter.id}: #{e.message}"
    @stats = { verses_count: 0, words_count: 0, pages: 'N/A', rukus_count: 'N/A' }
  end

  def ayah
    @translations = @verse.translations.includes(:resource_content, :language)
    @tafsirs = @verse.tafsirs.includes(:resource_content, :language)
    @audio_files = @verse.audio_files.includes(:recitation)
    @words = @verse.words.includes(:word_translations, :root, :lemma, :stem).order(:position)
    @morphology_words = @verse.morphology_words.includes(:grammar_concepts)
  end

  def word
    @translations = @word.word_translations.includes(:language)
    @morphology_word = @word.morphology_word
    @related_words = Word.where(root_id: @word.root_id).where.not(id: @word.id).limit(10) if @word.root_id
  end

  private

  def load_chapter
    @chapter = Chapter.find_by(chapter_number: params[:surah_id]) || Chapter.find(params[:surah_id])
    redirect_to quran_explorer_path unless @chapter
  end

  def load_verse
    if params[:ayah_id]
      @verse = @chapter.verses.find_by(verse_number: params[:ayah_id])
    elsif params[:verse_key]
      @verse = Verse.find_by(verse_key: params[:verse_key])
      @chapter = @verse.chapter if @verse
    end
    redirect_to quran_explorer_surah_path(@chapter.chapter_number) unless @verse
  end

  def load_word
    if params[:word_id]
      @word = @verse.words.find(params[:word_id])
    elsif params[:word_position]
      @word = @verse.words.find_by(position: params[:word_position])
    end
    redirect_to quran_explorer_ayah_path(@chapter.chapter_number, @verse.verse_number) unless @word
  end
end