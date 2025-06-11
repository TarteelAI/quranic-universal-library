class VersesController < CommunityController
  def compare
    keys = ayah_keys
    @verses = Verse.where(verse_key: keys)
                   .includes(:words)
                   .order(Arel.sql("ARRAY_POSITION(ARRAY[#{keys.map { |k| "'#{k}'" }.join(",")}]::text[], verses.verse_key::text)"))

    @show_translation = params[:resource].present? && ResourceContent.translations.where(id: params[:resource]).present?

    if @show_translation
      @verses = @verses
        .eager_load(:translation)
        .where(translation: { resource_content_id: params[:resource] })
        .order('words.position ASC')
    end
  end

  protected
  def ayah_keys
    params[:ayahs].to_s.split(',').map(&:strip).compact_blank
  end
end
