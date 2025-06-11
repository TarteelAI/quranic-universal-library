class ReadersController < CommunityController
  before_action :load_resource_access, only: :show

  def show
    @ayah_pairs = parse_ayahs(params[:ayahs])

    if params[:resource].present?
      @resource = ResourceContent.find_by(id: params[:resource])
      flash.now[:alert] = "Resource ##{params[:resource]} not found." unless @resource
    end

    @entries = @ayah_pairs.map do |surah, ayah|
      verse = Verse.find_by(chapter_id: surah, verse_number: ayah)
      translation = @resource && verse ? verse.translations.find_by(resource_content_id: @resource.id) : nil
      { verse: verse, translation: translation }
    end
  end

  private

  def parse_ayahs(str)
    return [] if str.blank?

    str.split(',').each_with_object([]) do |segment, arr|
      parts = segment.split(':')
      next unless parts.size == 2

      surah, ayah = parts.map(&:to_i)
      arr << [surah, ayah] if surah.positive? && ayah.positive?
    end
  end

  def load_resource_access
    @access = false

    if params[:resource].present?
      @resource = ResourceContent.find_by(id: params[:resource])
      @access = can_manage?(@resource) if @resource
    end
  end
end
