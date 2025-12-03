class TafsirProofreadingsController < CommunityController
  before_action :find_resource
  before_action :authenticate_user!, only: %i[edit update]
  before_action :authorize_access!, only: %i[edit update]
  def show
    #TODO: use presenter to load data
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
    params[:verse_number].to_i if params[:verse_number].present?
  end

  def tafsir_params
    params
      .require(:tafsir)
      .permit(:text, :start_verse_id, :end_verse_id)
  end

  def find_resource
    return @resource if @resource

    if params[:id]
      @resource = Tafsir.find(params[:id]).get_resource_content
    else
      params[:resource_id] ||= 169
      @resource = ResourceContent.find(params[:resource_id])
    end

    @presenter.set_resource(@resource)
  end

  def load_resource_access
    @access = can_manage?(find_resource)
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

    tafsirs.order("#{sort_key} #{sort_order}")
  end

  def find_tafsir(resource)
    if params[:verse_key]
      filter_tafsirs(resource).first
    else
      Tafsir.where(resource_content_id: resource.id).find(params[:id])
    end
  end

  def sort_key
    sort_by = params[:sort_key].to_s.presence || 'id'

    if ['id', 'group_verse_key_from', 'group_verses_count', 'group_verse_key_to'].include?(sort_by)
      sort_by
    else
      'verse_id'
    end
  end

  def init_presenter
    @presenter = TafsirPresenter.new(self)
  end
end
