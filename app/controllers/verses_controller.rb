class VersesController < CommunityController
  before_action :set_presenter
  def compare
    ids = prepare_verse_ids
    @translation_ids = prepare_translation_ids
    @verses = Verse.where(id: ids)
                   .includes(:words)
                   .order(Arel.sql("ARRAY_POSITION(ARRAY[#{ids.map { |k| "'#{k}'" }.join(",")}]::text[], verses.id::text)"))

    @show_translation = @translation_ids && ResourceContent.translations.where(id: @translation_ids).present?

    if @show_translation
      @verses = @verses
                  .eager_load(:translations)
                  .where(translations: { resource_content_id: @translation_ids })
                  .order('words.position ASC')
    end
  end

  protected

  def prepare_verse_ids
    return [] unless params[:ayahs].present?
    ids = []

    params[:ayahs].to_s.split(',').map(&:strip).each do |part|
      if part.include?('-')
        from, to = part.split('-')
        from = Utils::Quran.get_ayah_id_from_key(from.strip)
        to = Utils::Quran.get_ayah_id_from_key(to.strip)
        if from && to
          ids += (from..to).to_a
        end
      else
        if part.match?(/^\d+:\d+$/)
          ids << Utils::Quran.get_ayah_id_from_key(part)
        end
      end
    end

    ids.uniq
  end

  def prepare_translation_ids
    ids = params[:resource_ids]
    return [] if ids.blank?

    ids = if ids.is_a?(Array)
            ids.compact_blank
          else
            ids.split(',').compact_blank
          end

    # Limit to 10 translations for performance
    ids.first(10)
  end

  def set_presenter
    @presenter = VersesPresenter.new(self)
  end
end
