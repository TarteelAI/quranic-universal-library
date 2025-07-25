module V1
  class ChapterPresenter < ApplicationPresenter
    def chapters
      finder.chapters
    end

    def chapter
      finder.chapter(params[:id]) || invalid_chapter(params[:id])
    end

    def finder
      @finder ||= ::V1::ChapterFinder.new(locale: api_locale)
    end
  end
end