class VersesController < CommunityController
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
    # params[:ayahs].to_s.split(',').map(&:strip).compact_blank
    return [] unless params[:ayahs].present?
    keys = []

    params[:ayahs].to_s.split(',').map(&:strip).each do |part|
      if part.include?('-')
        from, to = part.split('-')
        from_surah, from_ayah = from.split(':').map(&:to_i)
        to_surah, to_ayah = to.split(':').map(&:to_i)

        if from_surah == to_surah
          (from_ayah..to_ayah).each do |ayah_number|
            keys << "#{from_surah}:#{ayah_number}"
          end
        else
          # Optionally handle multi-surah ranges here if needed
          raise ArgumentError, "Cross-surah ranges not supported: #{part}"
        end
      else
        keys << part if part.match?(/^\d+:\d+$/)
      end
    end

    Verse.unscoped.where(verse_key: keys).pluck(:id)
  end
  
  def prepare_translation_ids
    ids = params[:resource_ids]
    return [] if ids.blank?

    if ids.is_a?(Array)
      ids.compact_blank
    else
      ids.split(',').compact_blank
    end
  end
end
