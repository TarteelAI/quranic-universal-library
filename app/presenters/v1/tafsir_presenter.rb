module V1
  class TafsirPresenter < ApiPresenter
    def tafsirs_for_ayah
      ayah_key = params[:ayah_key]
      language_code = params[:language]
      resource_ids = params[:resource_ids].to_s.split(',').map(&:strip)

      finder = TafsirFinder.new(
        resource_content_id: nil,
        locale: api_locale,
        current_page: current_page,
        per_page: per_page
      )
      
      tafsirs = finder.for_ayah(
        ayah_key: ayah_key,
        language_code: language_code,
        resource_content_ids: resource_ids,
      )

      if tafsirs.any?
        ids = tafsirs.map(&:resource_content_id).uniq
        resources = ResourceContent.where(id: ids)
        eager_load_best_names(resources, resource_type: ResourceContent)
      end

      tafsirs
    end

    def tafsirs_by_range
      @resource_content = find_resource_content
      ids = parse_ayah_range

      raise ActionController::ParameterMissing.new('from/to or ayah_keys') if ids.empty?
      
      finder = TafsirFinder.new(
        resource_content_id: @resource_content.id,
        locale: api_locale,
        current_page: current_page,
        per_page: per_page
      )

      finder.for_ayahs(ids)
    end

    def random_tafsir
      verses = Verse.unscoped
      chapter = filter_chapter

      if chapter.present?
        verses = verses.where(chapter_id: chapter)
      end

      params[:ayah_key] = verses.order('RANDOM()').limit(1).first.verse_key

      tafsirs_for_ayah.first
    end

    def resource_content
      @resource_content ||= find_resource_content
    end

    private

    def find_resource_content
      resource_id = params[:resource_id] || params[:id]
      resource = ResourceContent.tafsirs.approved.includes(:language).find_by(id: resource_id)
      
      if resource.blank?
        raise ::Api::RecordNotFound.new("Tafsir resource with ID #{resource_id} not found")
      end
      
      resource
    end

    def parse_ayah_range
      verse_ids = []
      
      if params[:from].present? && params[:to].present?
        from_id = Utils::Quran.get_ayah_id_from_key(params[:from].to_s.strip)
        to_id = Utils::Quran.get_ayah_id_from_key(params[:to].to_s.strip)
        
        if from_id && to_id && from_id <= to_id
          verse_ids = (from_id..to_id).to_a
        end
      elsif params[:ayah_keys].present?
        params[:ayah_keys].to_s.split(',').map(&:strip).each do |part|
          if part.include?('-')
            from_key, to_key = part.split('-').map(&:strip)
            from_id = Utils::Quran.get_ayah_id_from_key(from_key)
            to_id = Utils::Quran.get_ayah_id_from_key(to_key)
            if from_id && to_id && from_id <= to_id
              verse_ids += (from_id..to_id).to_a
            end
          elsif part.match?(/^\d+:\d+$/)
            verse_id = Utils::Quran.get_ayah_id_from_key(part)
            verse_ids << verse_id if verse_id
          end
        end
      end
      
      verse_ids.uniq.compact
    end
  end
end

