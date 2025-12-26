class AyahController < ApplicationController
  def show
    if request.xhr? || request.format.turbo_stream?
      render layout: false
    end
  end

  def text
    render partial: 'ayah/ayah_text', layout: false
  end

  def translations
    render partial: 'ayah/translations', layout: false
  end

  def tafsirs
    render partial: 'ayah/tafsirs', layout: false
  end

  def words
    render partial: 'ayah/words', layout: false
  end

  def theme
    render partial: 'ayah/theme', layout: false
  end

  def transliteration
    render partial: 'ayah/transliteration', layout: false
  end

  def topics
    render partial: 'ayah/topics', layout: false
  end

  def topic
    @topic = Topic.find_by(id: params[:topic_id])
    return head :not_found unless @topic
    @verse_topics = @topic.verse_topics.includes(verse: [:chapter, :words, :translations]).to_a
    render partial: 'ayah/topic', layout: false
  end

  def recitation
    render partial: 'ayah/recitation', layout: false
  end

  protected

  def init_presenter
    @presenter = AyahPresenter.new(self)
    @ayah = @presenter.ayah
    head :not_found unless @presenter.found?
  end
end