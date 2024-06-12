class TafsirProofreadingsController < CommunityController
  before_action :find_resource
  before_action :check_permission, only: %i[edit update create]

  def show
    @tafisr = find_tafsir(@resource)
  end

  def edit
    @tafisr = find_tafsir(@resource)
  end

  def update
    @tafisr = find_tafsir(@resource)

    if @tafisr.save_suggestions(tafsir_params, current_user)
      redirect_to tafsir_proofreading_path(@tafisr.id, verse_id: @tafisr.group_tafsir_id, resource_id: @resource.id),
                  notice: "Your suggestions are saved successfully"
    else
      render action: :edit, alert: @tafisr.errors.full_messages
    end
  end

  def index
    @tafsir_list = ResourceContent.tafsirs

    @pagy, @ayah_tafisrs = pagy(filter_tafsirs(@resource))
  end

  protected

  def verse_id
    if params[:verse_id].present?
      params[:verse_id].to_i
    elsif params[:verse_key].present?
      Utils::Quran.get_ayah_id_from_key(params[:verse_key])
    elsif chapter_number && verse_number
      Utils::Quran.get_ayah_id_from_key("#{chapter_number}:#{verse_number}")
    end
  end

  def chapter_number
    params[:filter_chapter].to_i if params[:filter_chapter].present?
  end

  def verse_number
    params[:filter_verse].to_i if params[:filter_verse].present?
  end

  def tafsir_params
    params
      .require(:tafsir)
      .permit(:text, :start_verse_id, :end_verse_id)
  end

  def find_resource
    if params[:id]
      @resource = Tafsir.find(params[:id]).get_resource_content
    else
      params[:resource_id] ||= 169
      @resource = ResourceContent.find(params[:resource_id])
    end
  end

  def check_permission
    @access = can_manage?(@resource)

    unless @access
      url = tafsir_proofreading_path(params[:id], resource_id: @resource.id)
      redirect_to url, alert: "Sorry you don't have access to this resource."
    end
  end

  def filter_tafsirs(resource)
    tafsirs = Tafsir.where(resource_content_id: resource.id)

    if verse_id
      tafsirs = tafsirs
                  .where(":ayah >= start_verse_id AND :ayah <= end_verse_id ", ayah: verse_id)
    elsif chapter_number
      tafsirs = tafsirs.where(chapter_id: chapter_number)
    end

    if params[:query].present?
      tafsirs = tafsirs.text_search(params[:query])
    end

    if params[:sort_key].present?
      sort_by = params[:sort_key].strip
      sort_order = params[:sort_order].to_s.presence || 'ASC'
      tafsirs = tafsirs.order("#{sort_by} #{sort_order}")
    else
      tafsirs = tafsirs.order('verse_id ASC')
    end

    tafsirs
  end

  def find_tafsir(resource)
    if params[:verse_key]
      filter_tafsirs(resource).first
    else
      Tafsir.where(resource_content_id: resource.id).find(params[:id])
    end
  end
end
